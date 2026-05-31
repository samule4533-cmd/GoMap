-- ============================================================
-- appointments: 그룹 내 약속 (모임장이 만들고 멤버가 투표)
-- ============================================================
-- 모임장 = 그룹의 owner_id. 그룹과 분리해서 owner_id 를 보관하는 이유는
-- 그룹 owner 위임(transfer_group_ownership) 후에도 약속의 "만든 사람" 기록을
-- 잃지 않기 위함.
--
-- status:
--   open   : 투표 진행 중
--   tie    : 자동 마감했는데 동률. 모임장이 resolve_appointment_tie 로 확정해야 함
--   closed : 확정됨. winning_place_id 필수.
create table appointments (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references groups(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  memo text,
  deadline_at timestamptz not null,
  status text not null default 'open'
    check (status in ('open', 'tie', 'closed')),
  winning_place_id uuid references places(id) on delete set null,
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (status = 'closed' and winning_place_id is not null and closed_at is not null)
    or (status = 'tie' and winning_place_id is null and closed_at is not null)
    or (status = 'open' and winning_place_id is null and closed_at is null)
  )
);

create index appointments_group_id_idx on appointments(group_id);
create index appointments_status_deadline_idx on appointments(status, deadline_at);

create trigger appointments_set_updated_at
  before update on appointments
  for each row
  execute function set_updated_at();

alter table appointments enable row level security;

-- 약속 row 직접 select 는 본인이 그 그룹의 멤버일 때만.
-- 변경은 모두 RPC.
create policy "appointments_select_group_member"
  on appointments for select
  using (
    exists (
      select 1 from group_members gm
      where gm.group_id = appointments.group_id
        and gm.user_id = auth.uid()
    )
  );

-- ============================================================
-- candidate_places: 약속 후보 장소 (한 약속에 2~5개)
-- ============================================================
-- 같은 place 가 같은 약속에 중복 후보로 들어가는 것은 차단.
-- 개수 제약(2~5)은 RPC 에서 검증한다 (DB level check 는 row count 를
-- 다루기 어려움).
create table candidate_places (
  id uuid primary key default gen_random_uuid(),
  appointment_id uuid not null references appointments(id) on delete cascade,
  place_id uuid not null references places(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (appointment_id, place_id)
);

create index candidate_places_appointment_idx on candidate_places(appointment_id);

alter table candidate_places enable row level security;

-- 후보 직접 select 도 같은 그룹 멤버일 때만.
create policy "candidate_places_select_group_member"
  on candidate_places for select
  using (
    exists (
      select 1
      from appointments a
      join group_members gm on gm.group_id = a.group_id
      where a.id = candidate_places.appointment_id
        and gm.user_id = auth.uid()
    )
  );

-- ============================================================
-- votes: 멤버 투표 (1인 1표, 변경 가능)
-- ============================================================
-- pk(appointment_id, voter_id) 로 1인 1표 강제. 후보 변경은 upsert.
create table votes (
  appointment_id uuid not null references appointments(id) on delete cascade,
  voter_id uuid not null references auth.users(id) on delete cascade,
  candidate_id uuid not null references candidate_places(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (appointment_id, voter_id)
);

create index votes_candidate_idx on votes(candidate_id);

create trigger votes_set_updated_at
  before update on votes
  for each row
  execute function set_updated_at();

alter table votes enable row level security;

-- 본인 투표만 직접 select. 다른 멤버 투표 통계는 RPC 로 노출.
create policy "votes_select_own"
  on votes for select
  using (auth.uid() = voter_id);

-- ============================================================
-- RPC: 약속 생성 (그룹 owner only)
-- ============================================================
-- place_ids 는 places.id 배열. 호출 전에 클라이언트가 places 에 upsert 해서
-- id 를 확보한 뒤 전달한다. 개수 2~5개, deadline 은 미래여야 한다.
create or replace function create_appointment(
  target_group_id uuid,
  appointment_memo text,
  deadline_at timestamptz,
  place_ids uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid;
  new_appointment_id uuid;
  place_count int;
  valid_place_count int;
begin
  current_user_id := auth.uid();
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if not exists (
    select 1 from groups
    where id = target_group_id and owner_id = current_user_id
  ) then
    raise exception 'Only group owner can create an appointment';
  end if;

  if deadline_at is null or deadline_at <= now() then
    raise exception 'deadline_at must be in the future';
  end if;

  place_count := coalesce(array_length(place_ids, 1), 0);
  if place_count < 2 or place_count > 5 then
    raise exception 'Appointment must have 2~5 candidate places (got %)', place_count;
  end if;

  -- 중복 제거된 실제 places 행 수와 입력 배열 길이가 같아야 함.
  -- (배열 안에 중복 id 가 있거나 존재하지 않는 id 가 섞이면 거부)
  select count(distinct id) into valid_place_count
  from places
  where id = any(place_ids);

  if valid_place_count <> place_count then
    raise exception 'Some place_ids are invalid or duplicated';
  end if;

  insert into appointments (group_id, owner_id, memo, deadline_at)
  values (target_group_id, current_user_id, nullif(trim(coalesce(appointment_memo, '')), ''), deadline_at)
  returning id into new_appointment_id;

  insert into candidate_places (appointment_id, place_id)
  select new_appointment_id, p
  from unnest(place_ids) as p;

  return new_appointment_id;
end;
$$;

-- ============================================================
-- RPC: 투표 (그룹 멤버 누구나, 모임장 포함)
-- ============================================================
-- upsert 라 같은 사람이 후보를 바꾸면 한 표만 유지. 마지막 멤버가
-- 투표해서 전원 완료되면 maybe_close_appointment 로 자동 마감 시도.
create or replace function cast_vote(
  target_appointment_id uuid,
  target_candidate_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid;
  a_group_id uuid;
  a_status text;
  a_deadline timestamptz;
begin
  current_user_id := auth.uid();
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select group_id, status, deadline_at
    into a_group_id, a_status, a_deadline
  from appointments
  where id = target_appointment_id;

  if a_group_id is null then
    raise exception 'Appointment not found';
  end if;

  if a_status <> 'open' then
    raise exception 'Appointment is not open for voting';
  end if;

  if a_deadline <= now() then
    raise exception 'Appointment voting deadline has passed';
  end if;

  if not exists (
    select 1 from group_members
    where group_id = a_group_id and user_id = current_user_id
  ) then
    raise exception 'Only group members can vote';
  end if;

  if not exists (
    select 1 from candidate_places
    where id = target_candidate_id and appointment_id = target_appointment_id
  ) then
    raise exception 'Candidate does not belong to this appointment';
  end if;

  insert into votes (appointment_id, voter_id, candidate_id)
  values (target_appointment_id, current_user_id, target_candidate_id)
  on conflict (appointment_id, voter_id)
  do update set candidate_id = excluded.candidate_id, updated_at = now();

  -- 전원 투표 완료면 자동 마감 시도.
  perform maybe_close_appointment(target_appointment_id);
end;
$$;

-- ============================================================
-- RPC: 자동 마감 시도 (lazy close)
-- ============================================================
-- 호출 시점에 다음 중 하나면 close:
--   1) 현재 그룹 멤버 전원이 투표 완료
--   2) deadline_at <= now()
-- 다수결 winner 가 단일이면 status='closed', 동률이면 status='tie'.
-- 투표가 한 표도 없는 채로 마감되면 winner 가 없으므로 status='tie'.
-- 그룹 멤버 변동(나감/추가) 후에도 "현재 멤버 기준 전원" 으로 판정한다.
create or replace function maybe_close_appointment(
  target_appointment_id uuid
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid;
  a_group_id uuid;
  a_status text;
  a_deadline timestamptz;
  member_count int;
  voter_count int;
  deadline_passed boolean;
  all_voted boolean;
  top_count int;
  winner_count int;
  winner_place uuid;
begin
  current_user_id := auth.uid();
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select group_id, status, deadline_at
    into a_group_id, a_status, a_deadline
  from appointments
  where id = target_appointment_id;

  if a_group_id is null then
    raise exception 'Appointment not found';
  end if;

  if a_status <> 'open' then
    return a_status;
  end if;

  -- 그룹 멤버만 호출 가능 (외부에서 임의로 close 시도 차단).
  if not exists (
    select 1 from group_members
    where group_id = a_group_id and user_id = current_user_id
  ) then
    raise exception 'Only group members can close an appointment';
  end if;

  deadline_passed := a_deadline <= now();

  select count(*) into member_count
  from group_members where group_id = a_group_id;

  select count(*) into voter_count
  from votes v
  join group_members gm on gm.group_id = a_group_id and gm.user_id = v.voter_id
  where v.appointment_id = target_appointment_id;

  all_voted := member_count > 0 and voter_count >= member_count;

  if not (all_voted or deadline_passed) then
    return 'open';
  end if;

  -- 다수결 계산. 현재 그룹 멤버의 투표만 카운트.
  with current_member_votes as (
    select v.candidate_id, cp.place_id
    from votes v
    join group_members gm
      on gm.group_id = a_group_id and gm.user_id = v.voter_id
    join candidate_places cp on cp.id = v.candidate_id
    where v.appointment_id = target_appointment_id
  ),
  tallies as (
    select place_id, count(*) as cnt
    from current_member_votes
    group by place_id
  ),
  max_cnt as (
    select max(cnt) as m from tallies
  )
  select max_cnt.m, count(*) into top_count, winner_count
  from tallies, max_cnt
  where tallies.cnt = max_cnt.m
  group by max_cnt.m;

  if top_count is null then
    -- 투표가 하나도 없음 -> tie
    update appointments
       set status = 'tie',
           closed_at = now()
     where id = target_appointment_id;
    return 'tie';
  end if;

  if winner_count = 1 then
    select place_id into winner_place
    from (
      select cp.place_id, count(*) as cnt
      from votes v
      join group_members gm
        on gm.group_id = a_group_id and gm.user_id = v.voter_id
      join candidate_places cp on cp.id = v.candidate_id
      where v.appointment_id = target_appointment_id
      group by cp.place_id
    ) t
    where cnt = top_count;

    update appointments
       set status = 'closed',
           winning_place_id = winner_place,
           closed_at = now()
     where id = target_appointment_id;
    return 'closed';
  end if;

  update appointments
     set status = 'tie',
         closed_at = now()
   where id = target_appointment_id;
  return 'tie';
end;
$$;

-- ============================================================
-- RPC: 동률 해소 (group owner only)
-- ============================================================
-- status='tie' 인 약속에 대해 모임장이 후보 중 하나를 winner 로 지정.
create or replace function resolve_appointment_tie(
  target_appointment_id uuid,
  winning_candidate_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid;
  a_group_id uuid;
  a_status text;
  winner_place uuid;
begin
  current_user_id := auth.uid();
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select group_id, status into a_group_id, a_status
  from appointments
  where id = target_appointment_id;

  if a_group_id is null then
    raise exception 'Appointment not found';
  end if;

  if a_status <> 'tie' then
    raise exception 'Appointment is not in tie state';
  end if;

  if not exists (
    select 1 from groups
    where id = a_group_id and owner_id = current_user_id
  ) then
    raise exception 'Only group owner can resolve a tie';
  end if;

  select place_id into winner_place
  from candidate_places
  where id = winning_candidate_id
    and appointment_id = target_appointment_id;

  if winner_place is null then
    raise exception 'Candidate does not belong to this appointment';
  end if;

  -- closed_at 도 함께 갱신. 테이블 CHECK 제약상 status='closed' 행은
  -- closed_at 이 not null 이어야 하고, 의미적으로도 "동률 해소를 통해
  -- 확정된 시각" 이 사용자에게 더 가치 있는 정보이므로 now() 로 덮어쓴다.
  update appointments
     set status = 'closed',
         winning_place_id = winner_place,
         closed_at = now()
   where id = target_appointment_id;
end;
$$;

-- ============================================================
-- RPC: 약속 취소 (현재 그룹장 only)
-- ============================================================
-- 약속의 owner_id (만든 사람) 가 아니라 "현재 그룹의 owner" 기준.
-- 약속 생성자가 그룹을 나가거나 모임장을 위임한 뒤에도 권한이 남는 문제를
-- 피한다. open / tie / closed 어떤 상태든 그룹장이 삭제할 수 있다.
-- candidate_places, votes 는 cascade 로 함께 삭제.
create or replace function cancel_appointment(
  target_appointment_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid;
  a_group_id uuid;
begin
  current_user_id := auth.uid();
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select group_id into a_group_id
  from appointments where id = target_appointment_id;

  if a_group_id is null then
    return;
  end if;

  if not exists (
    select 1 from groups
    where id = a_group_id and owner_id = current_user_id
  ) then
    raise exception 'Only current group owner can cancel an appointment';
  end if;

  delete from appointments where id = target_appointment_id;
end;
$$;

-- ============================================================
-- RPC: 그룹의 약속 목록 (멤버 전용)
-- ============================================================
-- 메타 정보만. 후보/투표 상세는 get_appointment_detail.
create or replace function list_group_appointments(
  target_group_id uuid
)
returns table (
  id uuid,
  group_id uuid,
  owner_id uuid,
  owner_nickname text,
  owner_tag text,
  memo text,
  deadline_at timestamptz,
  status text,
  winning_place_id uuid,
  winning_place_name text,
  closed_at timestamptz,
  candidate_count bigint,
  vote_count bigint,
  my_candidate_id uuid,
  created_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    a.id,
    a.group_id,
    a.owner_id,
    op.nickname as owner_nickname,
    op.tag as owner_tag,
    a.memo,
    a.deadline_at,
    a.status,
    a.winning_place_id,
    wp.name as winning_place_name,
    a.closed_at,
    (select count(*) from candidate_places cp where cp.appointment_id = a.id) as candidate_count,
    -- 현재 그룹 멤버 기준으로만 카운트. 나간 멤버의 표는 무시되어
    -- maybe_close_appointment 의 판정 기준과 일관성을 유지한다.
    (select count(*) from votes v
       join group_members gm
         on gm.group_id = a.group_id and gm.user_id = v.voter_id
       where v.appointment_id = a.id) as vote_count,
    (select v.candidate_id from votes v
       where v.appointment_id = a.id and v.voter_id = auth.uid()) as my_candidate_id,
    a.created_at
  from appointments a
  left join profiles op on op.id = a.owner_id
  left join places wp on wp.id = a.winning_place_id
  where a.group_id = target_group_id
    and exists (
      select 1 from group_members gm
      where gm.group_id = target_group_id
        and gm.user_id = auth.uid()
    )
  order by
    case a.status when 'open' then 0 when 'tie' then 1 else 2 end,
    a.deadline_at asc,
    a.created_at desc;
$$;

-- ============================================================
-- RPC: 약속 상세 (후보 + 후보별 투표수)
-- ============================================================
-- 후보 한 줄에 place 메타 + 표 수 + "내가 이 후보에 투표했는지" 플래그까지.
-- 단일 호출로 상세 화면 전체를 채울 수 있게.
create or replace function get_appointment_detail(
  target_appointment_id uuid
)
returns table (
  candidate_id uuid,
  place_id uuid,
  place_name text,
  place_address text,
  place_lat double precision,
  place_lng double precision,
  place_category text,
  vote_count bigint,
  is_my_vote boolean
)
language sql
security definer
set search_path = public
as $$
  select
    cp.id as candidate_id,
    p.id as place_id,
    p.name as place_name,
    p.address as place_address,
    p.lat as place_lat,
    p.lng as place_lng,
    p.category as place_category,
    -- list_group_appointments 와 동일하게 현재 그룹 멤버 기준 카운트.
    (select count(*) from votes v
       join appointments a2 on a2.id = v.appointment_id
       join group_members gm
         on gm.group_id = a2.group_id and gm.user_id = v.voter_id
       where v.candidate_id = cp.id) as vote_count,
    exists (
      select 1 from votes v
      where v.candidate_id = cp.id and v.voter_id = auth.uid()
    ) as is_my_vote
  from candidate_places cp
  join places p on p.id = cp.place_id
  where cp.appointment_id = target_appointment_id
    and exists (
      select 1
      from appointments a
      join group_members gm on gm.group_id = a.group_id
      where a.id = target_appointment_id
        and gm.user_id = auth.uid()
    )
  order by cp.created_at asc;
$$;

-- ============================================================
-- RPC 실행 권한 (defense in depth)
-- ============================================================
revoke all on function create_appointment(uuid, text, timestamptz, uuid[]) from public, anon;
grant execute on function create_appointment(uuid, text, timestamptz, uuid[]) to authenticated;

revoke all on function cast_vote(uuid, uuid) from public, anon;
grant execute on function cast_vote(uuid, uuid) to authenticated;

revoke all on function maybe_close_appointment(uuid) from public, anon;
grant execute on function maybe_close_appointment(uuid) to authenticated;

revoke all on function resolve_appointment_tie(uuid, uuid) from public, anon;
grant execute on function resolve_appointment_tie(uuid, uuid) to authenticated;

revoke all on function cancel_appointment(uuid) from public, anon;
grant execute on function cancel_appointment(uuid) to authenticated;

revoke all on function list_group_appointments(uuid) from public, anon;
grant execute on function list_group_appointments(uuid) to authenticated;

revoke all on function get_appointment_detail(uuid) from public, anon;
grant execute on function get_appointment_detail(uuid) to authenticated;
