-- ============================================================
-- places: 외부 provider(현재 kakao) 에서 가져온 장소 원본
-- ============================================================
-- 여러 사용자가 같은 장소를 저장해도 places 는 1행만 유지.
-- 약속의 후보 장소도 saved_places 도 모두 이 테이블을 참조한다.
create table places (
  id uuid primary key default gen_random_uuid(),
  provider text not null check (char_length(provider) between 1 and 32),
  provider_key text not null check (char_length(provider_key) between 1 and 128),
  name text not null check (char_length(name) between 1 and 200),
  address text,
  lat double precision not null,
  lng double precision not null,
  category text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider, provider_key)
);

create trigger places_set_updated_at
  before update on places
  for each row
  execute function set_updated_at();

alter table places enable row level security;

-- 로그인한 사용자라면 누구나 places 를 읽고 upsert 할 수 있다.
-- 장소 원본은 개인 정보가 아니고 공유 자산. saved_places / candidate_places
-- 쪽 RLS 가 실제 접근 통제를 담당한다.
create policy "places_select_authenticated"
  on places for select
  to authenticated
  using (true);

create policy "places_insert_authenticated"
  on places for insert
  to authenticated
  with check (true);

create policy "places_update_authenticated"
  on places for update
  to authenticated
  using (true)
  with check (true);

-- ============================================================
-- saved_places: 사용자별 즐겨찾기 (메모 + 공개범위)
-- ============================================================
-- (user_id, place_id) unique 로 중복 저장 차단.
-- visibility 는 PlaceVisibility enum 의 dbValue 와 1:1 매칭.
create table saved_places (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  place_id uuid not null references places(id) on delete cascade,
  memo text,
  visibility text not null default 'private'
    check (visibility in ('private', 'friends', 'selected_friends', 'public')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, place_id)
);

create index saved_places_user_id_idx on saved_places(user_id);
create index saved_places_place_id_idx on saved_places(place_id);

create trigger saved_places_set_updated_at
  before update on saved_places
  for each row
  execute function set_updated_at();

alter table saved_places enable row level security;

-- 본인 row 만 select/insert/update/delete. 친구 공개범위 기반 정책은
-- 친구 피드 작업 시점에 별도 마이그레이션으로 추가한다.
create policy "saved_places_select_own"
  on saved_places for select
  using (auth.uid() = user_id);

create policy "saved_places_insert_own"
  on saved_places for insert
  with check (auth.uid() = user_id);

create policy "saved_places_update_own"
  on saved_places for update
  using (auth.uid() = user_id);

create policy "saved_places_delete_own"
  on saved_places for delete
  using (auth.uid() = user_id);
