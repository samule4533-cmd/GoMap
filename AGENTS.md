## Git 작업 규칙

- 명시적으로 요청받지 않는 한 사용자 변경사항을 되돌리지 않는다.
- 수정 전과 마무리 전에 `git status --short`를 확인한다.
- 커밋은 범위를 작고 명확하게 유지한다. 
- 커밋 및 push는 하지 않는다. 개발자가 직접 하도록 한다.
- `.env`, IDE 파일, 생성된 빌드 결과, keystore, 로컬 네이티브 설정은 커밋하지 않는다.

## Git 커밋 컨벤션
- build: 시스템 또는 외부 종속성에 영향을 미치는 변경사항 (npm, gulp, yarn 레벨)
- chore: 패키지 매니저 설정할 경우, 코드 수정 없이 설정을 변경
- docs: documentation 변경
- feat: 새로운 기능
- fix: 버그 수정
- hotfix: 급한 버그 수정
- perf: 성능 개선
- refactor: 버그를 수정하거나 기능을 추가하지 않는 코드 변경, 리팩토링
- style: 코드 의미에 영향을 주지 않는 변경사항 ( white space, formatting, colons )
- test: 누락된 테스트 추가 또는 기존 테스트 수정
- revert: 작업 되돌리기

