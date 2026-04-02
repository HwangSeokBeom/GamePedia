# Xcode Scheme / Branch 운영 가이드

GamePedia 브랜치 역할:

- `dev`: 기능 개발과 일상 작업
- `staging`: 안정화, QA, 배포 전 검증
- `main`: 실제 운영 배포 기준

환경별 scheme 책임:

- `GamePedia-Dev`: dev 작업용
- `GamePedia-Staging`: staging 검증용
- `GamePedia-Prod`: production 검증, Release 실행, Archive 전용

운영 원칙:

1. `dev` 브랜치에서는 `GamePedia-Prod.xcscheme`를 일상적으로 수정하거나 재생성하지 않습니다.
2. 평소 실행/디버깅은 `GamePedia-Dev`, staging 확인은 `GamePedia-Staging`만 사용합니다.
3. `GamePedia-Prod.xcscheme` 변경은 정말 필요한 배포 작업일 때만 하고, 가능하면 별도 커밋으로 분리합니다.
4. scheme 관련 변경은 기능 코드와 섞지 말고 따로 커밋해서 `dev -> staging -> main` 승격 시 diff를 쉽게 확인합니다.
5. 환경 동작 변경은 가능하면 scheme 반복 수정이 아니라 `Debug / Staging / Release` + `xcconfig`에서 처리합니다.

머지 시 체크:

- `dev -> staging`: dev 작업 중 생긴 shared scheme diff가 배포용 scheme까지 섞이지 않았는지 확인합니다.
- `staging -> main`: `GamePedia-Prod.xcscheme`는 release 목적 변경만 포함되었는지 확인합니다.

Xcode가 scheme 파일을 자동 변경한 경우:

- 먼저 실제로 필요한 변경인지 확인합니다.
- 사용자별 파일(`xcuserdata`, `xcschememanagement.plist`)은 커밋하지 않습니다.
- 순서 변경, 기본 선택 scheme 변경, 개인 실행 상태 같은 노이즈면 되돌립니다.
- production scheme까지 같이 바뀌었으면 feature 커밋에 포함하지 말고 분리하거나 제외합니다.
