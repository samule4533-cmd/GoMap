-- ============================================================
-- groups: 그룹 (단톡방 모델)
-- ============================================================
-- owner_id = 모임장. 카톡 단톡방과 동일한 멘탈모델.
-- 일반 멤버는 멤버 추가/제거 권한 없음. 모임장만 가능.
-- 모임장이 leave 하면 가장 오래된 멤버에게 자동 위임. 멤버가 본인뿐이면 그룹 자동 삭제.
create table groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 30),
  owner_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table groups enable row level security;

-- 변경은 모두 RPC. 직접 select 우회 방지로 owner 인 row 만 허용.
-- 일반 멤버는 list_my_groups RPC 로 그룹 메타를 받는다.
create policy "groups_select_owner"
  on groups for select
  using (auth.uid() = owner_id);

create trigger groups_set_updated_at
  before update on groups
  for each row
  execute function set_updated_at();

-- ============================================================
-- group_members
-- ============================================================
-- (group_id, user_id) pk 로 중복 가입 차단.
create table group_members (
  group_id uuid not null references groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

alter table group_members enable row level security;

-- 본인 row 만 직접 select 가능. 다른 멤버 정보는 list_group_members RPC 로 노출.
create policy "group_members_select_own"
  on group_members for select
  using (auth.uid() = user_id);

-- ============================================================
-- RPC: 그룹 생성
-- ============================================================
-- 호출자 = owner. member_user_ids 각각이 호출자의 accepted 친구여야 한다.
-- owner 본인은 자동으로 group_members 에 추가된다.
create or replace function create_group(
  group_name text,
  member_user_ids uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid;
  new_group_id uuid;
  candidate_id uuid;
begin
  current_user_id := auth.uid();
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if group_name is null or char_length(trim(group_name)) = 0 then
    raise exception 'Group name required';
  end if;

  -- 친구 관계 검증. 본인은 스킵.
  foreach candidate_id in array coalesce(member_user_ids, array[]::uuid[]) loop
    if candidate_id = current_user_id then
      continue;
    end if;
    if not exists (
      select 1 from friendships
      where user_id = current_user_id
        and friend_id = candidate_id
        and status = 'accepted'
    ) then
      raise exception 'Member is not your friend: %', candidate_id;
    end if;
  end loop;

  insert into groups (name, owner_id)
  values (trim(group_name), current_user_id)
  returning id into new_group_id;

  -- owner 자동 가입
  insert into group_members (group_id, user_id)
  values (new_group_id, current_user_id);

  -- 멤버 가입 (본인 중복 / 동일 멤버 중복 모두 흡수)
  insert into group_members (group_id, user_id)
  select new_group_id, m
  from unnest(coalesce(member_user_ids, array[]::uuid[])) as m
  where m <> current_user_id
  on conflict do nothing;

  return new_group_id;
end;
$$;

-- ============================================================
-- RPC: 멤버 추가 (owner only)
-- ============================================================
create or replace function add_group_members(
  target_group_id uuid,
  member_user_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid;
  candidate_id uuid;
begin
  current_user_id := auth.uid();
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if not exists (
    select 1 from groups
    where id = target_group_id and owner_id = current_user_id
  ) then
    raise exception 'Only owner can add members';
  end if;

  foreach candidate_id in array coalesce(member_user_ids, array[]::uuid[]) loop
    if candidate_id = current_user_id then
      continue;
    end if;
    if not exists (
      select 1 from friendships
      where user_id = current_user_id
        and friend_id = candidate_id
        and status = 'accepted'
    ) then
      raise exception 'Member is not your friend: %', candidate_id;
    end if;
  end loop;

  insert into group_members (group_id, user_id)
  select target_group_id, m
  from unnest(coalesce(member_user_ids, array[]::uuid[])) as m
  where m <> current_user_id
  on conflict do nothing;
end;
$$;

-- ============================================================
-- RPC: 멤버 제거 (owner kick)
-- ============================================================
-- owner 가 자기 자신을 제거하는 경로는 leave_group 으로만.
create or replace function remove_group_member(
  target_group_id uuid,
  target_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid;
begin
  current_user_id := auth.uid();
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if not exists (
    select 1 from groups
    where id = target_group_id and owner_id = current_user_id
  ) then
    raise exception 'Only owner can remove members';
  end if;

  if target_user_id = current_user_id then
    raise exception 'Use leave_group to remove yourself';
  end if;

  delete from group_members
  where group_id = target_group_id
    and user_id = target_user_id;
end;
$$;

-- ============================================================
-- RPC: 그룹 나가기 (자동 위임 + 마지막 멤버면 그룹 삭제)
-- ============================================================
-- owner 가 나가면:
--   - 다른 멤버 있으면 가장 오래된 멤버 (joined_at asc) 에게 owner 위임
--   - 없으면 그룹 자체 삭제 (cascade 로 group_members 정리)
create or replace function leave_group(target_group_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid;
  group_owner_id uuid;
  successor_id uuid;
begin
  current_user_id := auth.uid();
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select owner_id into group_owner_id
  from groups where id = target_group_id;

  if group_owner_id is null then
    return;
  end if;

  if not exists (
    select 1 from group_members
    where group_id = target_group_id and user_id = current_user_id
  ) then
    return;
  end if;

  if group_owner_id = current_user_id then
    select user_id into successor_id
    from group_members
    where group_id = target_group_id
      and user_id <> current_user_id
    order by joined_at asc
    limit 1;

    if successor_id is null then
      delete from groups where id = target_group_id;
      return;
    end if;

    update groups
       set owner_id = successor_id
     where id = target_group_id;
  end if;

  delete from group_members
  where group_id = target_group_id
    and user_id = current_user_id;
end;
$$;

-- ============================================================
-- RPC: 명시적 위임
-- ============================================================
-- new_owner 는 이미 그룹 멤버여야 한다 (친구 관계 검증 X — 이미 멤버이므로).
create or replace function transfer_group_ownership(
  target_group_id uuid,
  new_owner_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid;
begin
  current_user_id := auth.uid();
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if not exists (
    select 1 from groups
    where id = target_group_id and owner_id = current_user_id
  ) then
    raise exception 'Only owner can transfer ownership';
  end if;

  if new_owner_id = current_user_id then
    raise exception 'Already the owner';
  end if;

  if not exists (
    select 1 from group_members
    where group_id = target_group_id and user_id = new_owner_id
  ) then
    raise exception 'New owner must be a group member';
  end if;

  update groups
     set owner_id = new_owner_id
   where id = target_group_id;
end;
$$;

-- ============================================================
-- RPC: 그룹 삭제 (owner only)
-- ============================================================
create or replace function delete_group(target_group_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid;
begin
  current_user_id := auth.uid();
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if not exists (
    select 1 from groups
    where id = target_group_id and owner_id = current_user_id
  ) then
    raise exception 'Only owner can delete group';
  end if;

  delete from groups where id = target_group_id;
end;
$$;

-- ============================================================
-- RPC: 그룹 이름 변경 (owner only)
-- ============================================================
create or replace function rename_group(
  target_group_id uuid,
  new_name text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid;
begin
  current_user_id := auth.uid();
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if new_name is null or char_length(trim(new_name)) = 0 then
    raise exception 'Group name required';
  end if;

  if not exists (
    select 1 from groups
    where id = target_group_id and owner_id = current_user_id
  ) then
    raise exception 'Only owner can rename group';
  end if;

  update groups
     set name = trim(new_name)
   where id = target_group_id;
end;
$$;

-- ============================================================
-- RPC: 내 그룹 목록
-- ============================================================
-- 내가 속한 그룹 + 모임장 정보 + 멤버 수 + is_owner 플래그.
create or replace function list_my_groups()
returns table (
  id uuid,
  name text,
  owner_id uuid,
  owner_nickname text,
  owner_tag text,
  member_count bigint,
  is_owner boolean,
  joined_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    g.id,
    g.name,
    g.owner_id,
    op.nickname as owner_nickname,
    op.tag as owner_tag,
    (select count(*) from group_members gm2 where gm2.group_id = g.id) as member_count,
    (g.owner_id = auth.uid()) as is_owner,
    gm.joined_at
  from group_members gm
  join groups g on g.id = gm.group_id
  left join profiles op on op.id = g.owner_id
  where gm.user_id = auth.uid()
  order by gm.joined_at desc;
$$;

-- ============================================================
-- RPC: 그룹 멤버 목록 (호출자가 그룹 멤버일 때만)
-- ============================================================
-- 정렬: owner 먼저, 그다음 가입 순.
create or replace function list_group_members(target_group_id uuid)
returns table (
  user_id uuid,
  nickname text,
  tag text,
  joined_at timestamptz,
  is_owner boolean
)
language sql
security definer
set search_path = public
as $$
  select
    gm.user_id,
    p.nickname,
    p.tag,
    gm.joined_at,
    (g.owner_id = gm.user_id) as is_owner
  from group_members gm
  join groups g on g.id = gm.group_id
  left join profiles p on p.id = gm.user_id
  where gm.group_id = target_group_id
    and exists (
      select 1 from group_members me
      where me.group_id = target_group_id
        and me.user_id = auth.uid()
    )
  order by (g.owner_id = gm.user_id) desc, gm.joined_at asc;
$$;

-- ============================================================
-- RPC 실행 권한 (defense in depth, friendships 마이그레이션과 동일 패턴)
-- ============================================================
revoke all on function create_group(text, uuid[]) from public, anon;
grant execute on function create_group(text, uuid[]) to authenticated;

revoke all on function add_group_members(uuid, uuid[]) from public, anon;
grant execute on function add_group_members(uuid, uuid[]) to authenticated;

revoke all on function remove_group_member(uuid, uuid) from public, anon;
grant execute on function remove_group_member(uuid, uuid) to authenticated;

revoke all on function leave_group(uuid) from public, anon;
grant execute on function leave_group(uuid) to authenticated;

revoke all on function transfer_group_ownership(uuid, uuid) from public, anon;
grant execute on function transfer_group_ownership(uuid, uuid) to authenticated;

revoke all on function delete_group(uuid) from public, anon;
grant execute on function delete_group(uuid) to authenticated;

revoke all on function rename_group(uuid, text) from public, anon;
grant execute on function rename_group(uuid, text) to authenticated;

revoke all on function list_my_groups() from public, anon;
grant execute on function list_my_groups() to authenticated;

revoke all on function list_group_members(uuid) from public, anon;
grant execute on function list_group_members(uuid) to authenticated;
