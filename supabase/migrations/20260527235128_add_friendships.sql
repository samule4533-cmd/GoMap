-- ============================================================
-- profiles: 제약 강화 + updated_at 트리거
-- ============================================================

-- nickname 은 표시명이라 자유도를 두되, 핸들 구분자인 # 와 공백 문자는 금지한다.
alter table profiles
  add constraint profiles_nickname_no_special
    check (nickname !~ '[#[:space:]]');

alter table profiles
  add constraint profiles_tag_no_special
    check (tag !~ '[#[:space:]]');

-- updated_at 자동 갱신. 클라이언트 시간 의존 제거.
create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
  before update on profiles
  for each row
  execute function set_updated_at();

-- ============================================================
-- friendships: 친구 관계
-- ============================================================
-- 양방향 관계를 2개 row 로 저장. (A→B, B→A 둘 다 insert.)
-- 직접 insert/update 는 RPC 로만 가능. 일반 정책 없음.
-- request_friend 는 양쪽 row 를 pending 으로 만들고 requested_by 에 요청자를 기록한다.
-- accept_friend_request 는 두 row 를 accepted 로 함께 갱신한다.
-- remove_friend 는 요청 취소/거절/친구 삭제를 모두 양방향 delete 로 처리한다.
create table friendships (
  user_id uuid not null references auth.users(id) on delete cascade,
  friend_id uuid not null references auth.users(id) on delete cascade,
  -- default 는 'pending'. fail safe: 어떤 코드가 status 명시를 빼먹어도
  -- 즉시 친구가 되지 않고 신청 대기로 떨어진다. 모든 RPC 는 명시적으로
  -- status 를 전달하므로 정상 흐름에서 default 가 실제로 쓰일 일은 없다.
  status text not null default 'pending'
    check (status in ('pending', 'accepted')),
  requested_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (user_id, friend_id),
  check (user_id <> friend_id)
);

alter table friendships enable row level security;

-- 본인이 user_id 인 row 만 select 가능.
-- insert/update/delete 정책은 의도적으로 두지 않는다. 양방향 2 row 구조라
-- 한쪽만 직접 변경하면 비대칭 깨짐. 모든 변경은 RPC (security definer) 만 거친다.
create policy "friendships_select_own"
  on friendships for select
  using (auth.uid() = user_id);

-- ============================================================
-- RPC: 친구 검색 (정확 매칭 only, 스크래핑 방지)
-- ============================================================
-- relation 을 응답에 함께 내려, 검색 결과 UI 에서 버튼 4분기
-- (none/pending_sent/pending_received/accepted) 를 한 번의 라운드트립으로
-- 처리할 수 있게 한다.
create or replace function search_profile_by_handle(
  search_nickname text,
  search_tag text
)
returns table (id uuid, nickname text, tag text, relation text)
language sql
security definer
set search_path = public
as $$
  select
    p.id,
    p.nickname,
    p.tag,
    coalesce(
      case
        when f.status = 'accepted' then 'accepted'
        when f.requested_by = auth.uid() then 'pending_sent'
        else 'pending_received'
      end,
      'none'
    ) as relation
  from profiles p
  left join friendships f
    on f.user_id = auth.uid()
   and f.friend_id = p.id
  where auth.uid() is not null
    and p.id <> auth.uid()
    and p.nickname = search_nickname
    and p.tag = search_tag
  limit 1;
$$;

-- ============================================================
-- RPC: 친구 요청 (양방향 pending insert)
-- ============================================================
-- 양쪽 row 모두 status='pending', requested_by=요청자 로 채운다.
-- 이미 어떤 관계가 있으면 on conflict do nothing 으로 조용히 통과시키고,
-- 호출자는 검색 응답의 relation 을 통해 현재 상태를 알 수 있다.
create or replace function request_friend(target_user_id uuid)
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
  if current_user_id = target_user_id then
    raise exception 'Cannot add yourself as friend';
  end if;

  -- UI 우회 호출로 프로필 없는 auth user id 가 friendship 에 들어가는 것을 막는다.
  if not exists (select 1 from profiles where id = target_user_id) then
    raise exception 'Target user has no profile';
  end if;

  insert into friendships (user_id, friend_id, status, requested_by)
  values (current_user_id, target_user_id, 'pending', current_user_id)
  on conflict do nothing;

  insert into friendships (user_id, friend_id, status, requested_by)
  values (target_user_id, current_user_id, 'pending', current_user_id)
  on conflict do nothing;
end;
$$;

-- ============================================================
-- RPC: 친구 요청 수락 (양방향 update to accepted)
-- ============================================================
-- 내가 받은 요청 (requested_by = requester_user_id 이고 내가 receiver) 만 수락.
-- 받은 요청이 아니면 noop.
create or replace function accept_friend_request(requester_user_id uuid)
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

  update friendships
     set status = 'accepted'
   where status = 'pending'
     and requested_by = requester_user_id
     and (
       (user_id = current_user_id and friend_id = requester_user_id)
       or (user_id = requester_user_id and friend_id = current_user_id)
     );
end;
$$;

-- ============================================================
-- RPC: 친구 삭제 (양방향 delete)
-- ============================================================
create or replace function remove_friend(target_user_id uuid)
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

  delete from friendships
  where (user_id = current_user_id and friend_id = target_user_id)
     or (user_id = target_user_id and friend_id = current_user_id);
end;
$$;

-- ============================================================
-- RPC: 내 친구 목록 (profile 조인)
-- ============================================================
-- profiles RLS 에 의해 친구의 profile 을 직접 select 못하므로
-- security definer 함수로 제한된 컬럼만 노출.
create or replace function list_my_friends()
returns table (id uuid, nickname text, tag text, created_at timestamptz)
language sql
security definer
set search_path = public
as $$
  select p.id, p.nickname, p.tag, f.created_at
  from friendships f
  join profiles p on p.id = f.friend_id
  where f.user_id = auth.uid()
    and f.status = 'accepted'
  order by f.created_at desc;
$$;

-- ============================================================
-- RPC: 내가 받은 친구 요청 목록 (profile 조인)
-- ============================================================
-- requested_by 가 상대(=friend_id) 인 경우만 "받은 요청" 으로 본다.
-- 내가 보낸 요청은 검색 결과의 pending_sent 로 확인하고, 여기서는 노출하지 않는다.
create or replace function list_my_pending_requests()
returns table (id uuid, nickname text, tag text, created_at timestamptz)
language sql
security definer
set search_path = public
as $$
  select p.id, p.nickname, p.tag, f.created_at
  from friendships f
  join profiles p on p.id = f.friend_id
  where f.user_id = auth.uid()
    and f.status = 'pending'
    and f.requested_by = f.friend_id
  order by f.created_at desc;
$$;

-- ============================================================
-- RPC 실행 권한 명시 (defense in depth)
-- ============================================================
-- security definer 함수는 기본적으로 PUBLIC 에 execute 권한이 있다.
-- 게다가 Supabase 는 새 함수 생성 시 anon/authenticated/service_role 에
-- default grant 를 부여하므로, public 만 revoke 하면 anon 권한이 남는다.
-- 익명 호출 자체를 차단하기 위해 public + anon 양쪽에서 revoke 한다.
-- service_role 은 서버 자동화용이라 권한 유지.
revoke all on function search_profile_by_handle(text, text) from public, anon;
grant execute on function search_profile_by_handle(text, text) to authenticated;

revoke all on function request_friend(uuid) from public, anon;
grant execute on function request_friend(uuid) to authenticated;

revoke all on function accept_friend_request(uuid) from public, anon;
grant execute on function accept_friend_request(uuid) to authenticated;

revoke all on function remove_friend(uuid) from public, anon;
grant execute on function remove_friend(uuid) to authenticated;

revoke all on function list_my_friends() from public, anon;
grant execute on function list_my_friends() to authenticated;

revoke all on function list_my_pending_requests() from public, anon;
grant execute on function list_my_pending_requests() to authenticated;
