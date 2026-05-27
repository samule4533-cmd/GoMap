-- 사용자 프로필 (닉네임 + 태그)
-- 친구 식별 = nickname#tag (예: "신승우#개발자")
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nickname text not null check (char_length(nickname) between 1 and 20),
  tag text not null check (char_length(tag) between 2 and 20),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (nickname, tag)
);

-- RLS
alter table profiles enable row level security;

-- 본인 프로필만 읽고/쓰기. 친구 검색용 정책은 friendships 마이그레이션에서 추가.
create policy "profiles_select_own"
  on profiles for select
  using (auth.uid() = id);

create policy "profiles_insert_own"
  on profiles for insert
  with check (auth.uid() = id);

create policy "profiles_update_own"
  on profiles for update
  using (auth.uid() = id);
