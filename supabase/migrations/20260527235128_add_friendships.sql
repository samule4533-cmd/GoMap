-- ============================================================
-- profiles: 제약 강화 + updated_at 트리거
-- ============================================================

-- nickname/tag 에 # 또는 공백 문자 금지 (앱 우회 방어).
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
--
-- status 와 requested_by 는 현재 MVP 에서는 항상 'accepted' / 요청자 로 채워진다.
-- 친구 공개 장소 / 그룹 초대 같은 신뢰 경계가 붙기 전에 request/accept 흐름을
-- 도입할 수 있도록 컬럼을 미리 둔다. 도입 시 마이그레이션 데이터 채움을
-- 줄이는 게 목적이다.
create table friendships (
  user_id uuid not null references auth.users(id) on delete cascade,
  friend_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'accepted'
    check (status in ('pending', 'accepted')),
  requested_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (user_id, friend_id),
  check (user_id <> friend_id)
);

alter table friendships enable row level security;

-- 본인이 user_id 인 row 만 select/delete.
create policy "friendships_select_own"
  on friendships for select
  using (auth.uid() = user_id);

create policy "friendships_delete_own"
  on friendships for delete
  using (auth.uid() = user_id);

-- ============================================================
-- RPC: 친구 검색 (정확 매칭 only, 스크래핑 방지)
-- ============================================================
-- is_friend 를 응답에 함께 내려, 검색 결과 UI 에서 "이미 친구" 분기를
-- 별도 라운드트립 없이 처리할 수 있게 한다.
create or replace function search_profile_by_handle(
  search_nickname text,
  search_tag text
)
returns table (id uuid, nickname text, tag text, is_friend boolean)
language sql
security definer
set search_path = public
as $$
  select
    p.id,
    p.nickname,
    p.tag,
    exists (
      select 1
      from friendships f
      where f.user_id = auth.uid()
        and f.friend_id = p.id
        and f.status = 'accepted'
    ) as is_friend
  from profiles p
  where auth.uid() is not null
    and p.id <> auth.uid()
    and p.nickname = search_nickname
    and p.tag = search_tag
  limit 1;
$$;

-- ============================================================
-- RPC: 친구 추가 (양방향 insert)
-- ============================================================
create or replace function add_friend(target_user_id uuid)
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
  values (current_user_id, target_user_id, 'accepted', current_user_id)
  on conflict do nothing;

  insert into friendships (user_id, friend_id, status, requested_by)
  values (target_user_id, current_user_id, 'accepted', current_user_id)
  on conflict do nothing;
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
