# GoMap 프로젝트 지침

## 프로젝트 맥락

GoMap은 지도 위에서 장소를 저장하고 공유하는 Flutter 모바일 앱이다. 제품 방향은 프라이빗한 지도 기반 장소 공유 SNS이며, 장소 자체를 콘텐츠로 보고 지도를 기본 피드로 사용한다.

현재 단계는 스켈레톤/MVP 기반 작업이다. 기능을 많이 붙이는 것보다 안정적인 구조와 작고 되돌리기 쉬운 변경을 우선한다.

## 기술 스택

- 앱: Flutter
- 상태 관리: Riverpod
- 지도: Mapbox
- 장소 검색: Naver Local Search API
- 백엔드: Supabase
- 데이터베이스: Supabase 기반 PostgreSQL

## 저장소 구조

- `lib/core/`: 상수, 테마, 공통 유틸
- `lib/models/`: `Place`, `SavedPlace`, `PlaceVisibility`, `NaverPlace` 등 도메인 모델
- `lib/services/`: Mapbox, Naver, Supabase 같은 외부 서비스 래퍼
- `lib/features/auth/`: 인증 UI와 provider
- `lib/features/map/`: 지도 화면, 지도 provider, 지도 위젯
- `lib/features/place/`: 장소 검색, 장소 저장, 장소 UI
- `android/`, `ios/`: Flutter 네이티브 플랫폼 설정

## 아키텍처 규칙

- 기능 코드는 `lib/features/<feature>/` 아래에 둔다.
- 외부 API 호출은 `lib/services/` 안에 둔다.
- 공유 도메인 데이터는 `lib/models/` 안에 둔다.
- Supabase, Naver, Mapbox API 호출을 위젯 안에 직접 넣지 않는다.
- 서비스 접근과 비동기 UI 상태는 Riverpod provider를 우선 사용한다.
- 현재의 `places`와 `saved_places` 분리를 유지한다.
  - `places`는 Naver 같은 provider에서 온 원본 장소 데이터다.
  - `saved_places`는 memo, visibility 같은 사용자별 저장 데이터다.
- Dart 코드에서는 공개 범위를 raw string이 아니라 `PlaceVisibility`로 다룬다.
- DB에 저장하는 문자열은 `PlaceVisibility.dbValue`를 사용한다.

## 현재 스켈레톤 상태

- Mapbox 토큰과 네이티브 설정이 끝나기 전까지 `mapbox_maps_flutter`는 비활성화/주석 상태일 수 있다.
- `MapboxService.init()`은 Mapbox SDK 활성화 전까지 placeholder일 수 있다.
- 검색 화면과 지도 화면은 아직 placeholder UI일 수 있다. UI가 비어 있다고 해서 구조가 잘못된 것으로 판단하지 않는다.
- Supabase 스키마는 아직 최종 확정 전이지만, 기본 방향은 `places` + `saved_places` 구조다.

## 환경 변수와 시크릿

- `.env`, 실제 API 키, Mapbox secret token, Supabase key, Naver secret, signing key, keystore, 로컬 머신 경로는 절대 커밋하지 않는다.
- 런타임 public token은 `.env`에 두고 `--dart-define`으로 전달한다.
- Mapbox download/secret token은 커밋되는 프로젝트 파일이 아니라 로컬 Gradle 설정에 둔다.
- `.env.example`에는 빈 placeholder만 둔다.
- 플랫폼 설정을 커밋하기 전에는 생성 파일과 로컬 IDE 파일이 계속 ignore되는지 확인한다.

## 자주 쓰는 명령

의존성 설치:

```bash
flutter pub get
```

정적 분석:

```bash
flutter analyze
```

테스트:

```bash
flutter test
```

Dart 포맷:

```bash
dart format lib test
```

환경 변수를 전달해서 실행 (`.env`에 있는 모든 키를 자동으로 `String.fromEnvironment`로 매핑):

```bash
flutter run --dart-define-from-file=.env
```

## 검증 흐름

- Dart 코드를 바꾼 뒤에는 `dart format lib test`를 실행한다.
- 작업 완료 전에는 `flutter analyze`를 실행한다.
- 로직, 모델, provider, 위젯 동작을 바꿨다면 `flutter test`를 실행한다.
- Mapbox나 네이티브 플랫폼 설정을 바꿨다면 가능한 경우 해당 iOS/Android 타깃에서 직접 확인한다.

## Flutter 코딩 규칙

- `flutter_lints`를 따른다.
- 큰 화면 파일 하나에 모든 코드를 넣기보다 소유 범위가 명확한 작은 위젯을 선호한다.
- UI가 앱 상태에 의존하면 `ConsumerWidget`이나 Riverpod provider를 사용한다.
- 비동기 로딩, 에러, 빈 상태를 명시적으로 처리한다.
- 스켈레톤 단계에서는 기반 구조를 강화하는 경우가 아니라면 큰 리팩터링을 피한다.
- 현재 제품 표면이 한국어이므로 UI 문구는 한국어를 우선 사용한다.

## 제품과 UI 방향

- 지도는 앱의 기본 화면이자 핵심 표면이다.
- 풀스크린 지도 위에 검색바, 마커, bottom sheet 같은 집중된 overlay를 얹는 방향을 선호한다.
- 디자인적으로(ui) 참고할 만한 github 공개 레포가 있다면 참고해서 사용해도 좋다. 그러나 그대로 가져와서 뺏겨 쓰는 형식은 피한다.
- 앱을 일반적인 스크롤 중심 SNS 피드로 만들지 않는다.
- 장소 카드는 제목, 주소/카테고리, 메모, 공개 범위, 소유자/친구 맥락을 중심으로 구성한다.
- MVP 우선순위는 지도 표시, 장소 검색, 장소 저장, 공개 범위, 친구가 볼 수 있는 장소다.

## 데이터베이스 방향

예상 핵심 스키마 방향:

- `places`
  - provider
  - provider_key
  - name
  - address
  - lat
  - lng
  - category
- `saved_places`
  - user_id
  - place_id
  - memo
  - visibility
  - created_at

필요한 unique 제약:

- `places`: `(provider, provider_key)` unique
- `saved_places`: 중복 저장 방지를 위해 `(user_id, place_id)` unique 고려

소셜 기능을 출시하기 전에는 Supabase RLS 정책으로 사용자 소유 데이터와 공개 범위 기반 접근을 통제한다.

## 로컬 개발 환경 방향

- Flutter 앱은 Docker 안에서 실행하지 않고 로컬 머신의 Flutter SDK, Android Emulator, iOS Simulator, 실제 기기로 실행한다.
- Supabase/PostgreSQL, migration, RLS, Edge Functions 검증이 필요해지는 시점에는 Supabase CLI 기반 local 개발환경을 사용한다. 이때 Docker가 필요하다.
- 환경은 `local`, `dev/staging`, `production`을 분리한다.
- production 데이터베이스를 직접 개발용으로 사용하지 않는다.
- Naver API secret처럼 모바일 앱에 넣으면 안 되는 값은 장기적으로 Supabase Edge Function 같은 서버 측 코드에서만 사용한다.

## 작업 참고 사항

- 큰 변화나 여러 파일을 건드리는 수정 후에는 `dart format lib test`와 `flutter analyze`를 실행하고, 발견된 format/lint 문제를 함께 수정한다.
- 로직, 모델, provider, 위젯 동작을 바꿨다면 가능한 범위에서 `flutter test`도 실행한다.
- 검증 명령을 실행하지 못했다면 최종 답변에 이유와 남은 리스크를 명확히 적는다.
- 항상 코드는 간단하게 작성한다. 현재 요구사항을 해결하지 않는 추상화, 범용화, 대규모 리팩터링은 피한다.
- 기존 구조와 네이밍을 우선 따른다. 새 패턴은 기존 방식으로 해결하기 어렵거나 중복을 의미 있게 줄일 때만 추가한다.
- 한 번에 너무 많은 기능을 섞지 않는다. 지도, 검색, 저장, 인증, DB 같은 변경은 가능하면 작은 단위로 나눠 진행한다.
- 에러 처리는 조용히 무시하지 않는다. 사용자에게 보여줄 상태, 로그, 예외 중 어떤 방식으로 처리할지 명확히 선택한다.
- API 키, 토큰, 로컬 경로, 개인 설정이 코드나 커밋 대상 파일에 들어가지 않았는지 항상 확인한다.
- 사용자가 작성 중인 변경사항을 덮어쓰거나 되돌리지 않는다. 같은 파일을 수정해야 하면 기존 변경을 읽고 그 위에 맞춰 작업한다.
- 디렉토리 구조는 각 역할에 맞게 분류한다. 그러나 너무 과도하게 나누지 않는다.

