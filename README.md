# GoMap

지도 기반 장소 저장 앱.

## 스택

- **Flutter** + **Riverpod**
- **Mapbox** — 지도
- **Kakao Local Search** — 장소 검색
- **Supabase** — 인증 / DB

## 폴더 구조

```
lib/
├── core/         상수, 테마
├── models/       Place, SavedPlace, PlaceVisibility, KakaoPlace
├── services/     Mapbox, Kakao, Supabase, Location
├── features/
│   ├── map/      지도 화면
│   ├── place/    검색 / 저장
│   └── auth/     로그인
└── main.dart
```

## 실행

```bash
cp .env.example .env   # 키 입력
flutter pub get
flutter run --dart-define-from-file=.env
```

## DB 스키마 (Supabase)

```sql
create table places (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  provider_key text not null,
  name text not null,
  address text,
  lat double precision not null,
  lng double precision not null,
  category text,
  created_at timestamptz default now(),
  unique (provider, provider_key)
);

create table saved_places (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  place_id uuid references places(id) on delete cascade,
  memo text,
  visibility text not null default 'private',
  created_at timestamptz default now()
);
```
