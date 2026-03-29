# GamePedia iOS App

GamePedia는 게임 정보를 탐색하고 리뷰를 작성하며, 플레이한 게임을 기록하고 공유할 수 있는 iOS 앱입니다.

왓챠피디아와 유사한 구조를 게임 도메인에 적용한 서비스로, 사용자가 게임을 검색하고 상세 정보를 확인하며, 리뷰와 평점을 남기고 자신의 라이브러리를 관리할 수 있도록 설계되었습니다.

## 1. 프로젝트 개요

GamePedia는 다양한 게임 정보를 한곳에서 탐색하고, 개인의 플레이 이력과 리뷰를 축적할 수 있도록 만든 iOS 애플리케이션입니다.

사용자는 인기 게임과 추천 게임을 확인할 수 있고, 원하는 게임을 검색한 뒤 상세 정보를 조회할 수 있습니다. 또한 찜한 게임, 플레이 상태, 작성한 리뷰를 기반으로 자신의 게임 라이브러리를 관리할 수 있습니다.

## 2. 앱 주요 기능

### 홈 화면
- 인기 게임 목록 제공
- 오늘의 추천 게임 제공
- 하이라이트 게임 노출

### 검색
- 게임 검색
- 검색 자동완성
- 다국어 검색 지원

### 게임 상세
- 게임 설명 확인
- 평점 확인
- 장르 정보 확인
- 플랫폼 정보 확인
- 번역된 설명 표시

### 라이브러리
- 플레이 중인 게임 관리
- 찜한 게임 목록 관리
- 작성한 리뷰 확인
- 플레이 상태 관리

### 리뷰 기능
- 리뷰 작성
- 평점 등록
- 리뷰 수정 및 삭제

### 인증 기능
- 이메일 로그인
- Apple 로그인
- Google 로그인
- JWT 기반 세션 관리

## 3. 기술 스택

- Swift
- UIKit
- Combine
- MVI Architecture
- Coordinator Pattern
- Clean Architecture
- UseCase / Repository Pattern
- IGDB API
- Core Server 연동
- Translate Server 연동

## 4. 아키텍처 설명

GamePedia는 UIKit 기반 iOS 앱이며, 화면 흐름과 비즈니스 로직, 데이터 접근 계층을 분리하기 위해 Clean Architecture와 Coordinator Pattern을 함께 사용합니다.

### Presentation Layer
- `ViewController`
- `View`
- `ViewModel (MVI)`

사용자 입력을 처리하고 상태를 화면에 반영하는 계층입니다.  
Combine을 사용해 상태 변경을 전달하며, ViewModel은 Intent를 받아 상태를 갱신합니다.

### Domain Layer
- `UseCase`

앱의 핵심 비즈니스 로직을 담당하는 계층입니다.  
각 기능은 UseCase 단위로 분리되어 있으며, Presentation 계층은 Domain 계층을 통해 필요한 동작을 수행합니다.

### Data Layer
- `Repository`
- `RemoteDataSource`

서버 통신 및 외부 API 연동을 담당하는 계층입니다.  
Repository는 Domain에 필요한 인터페이스를 제공하고, 실제 네트워크 요청은 RemoteDataSource를 통해 처리합니다.

### Coordinator
- 화면 전환 관리

ViewController 내부에 네비게이션 로직을 직접 두지 않고, Coordinator가 화면 전환을 전담합니다.  
이를 통해 화면 간 결합도를 낮추고, 흐름 제어를 명확하게 유지합니다.

## 5. 서버 구성 설명

GamePedia는 여러 서버와 연동하여 기능을 구성합니다.

### Core Server
- 사용자 인증 처리
- 게임 관련 메타데이터 제공
- 리뷰 및 라이브러리 데이터 관리
- IGDB API와의 중간 연동 계층 역할

Core Server는 앱이 직접 외부 서비스에 의존하지 않도록 중간 계층 역할을 수행하며, 비즈니스 로직과 사용자 데이터를 안정적으로 관리합니다.

### Translate Server
- 게임 설명 번역
- 다국어 텍스트 변환 지원
- 검색 및 상세 화면의 번역 보조

Translate Server를 통해 영어 기반 게임 데이터를 한국어 등 다른 언어로 변환하여 사용자 경험을 향상합니다.

## 6. 프로젝트 구조

```text
GamePedia/
├── Presentation/
│   ├── Home
│   ├── Search
│   ├── Detail
│   ├── Library
│   ├── Profile
├── Domain/
│   ├── UseCase
│   ├── Entity
├── Data/
│   ├── Repository
│   ├── API
├── Core/
│   ├── DIContainer
│   ├── Network
│   ├── Coordinator
```

## 7. 실행 방법

1. 저장소를 클론합니다.

```bash
git clone <repository-url>
cd GamePedia
```

2. Xcode에서 프로젝트를 엽니다.

```bash
open GamePedia.xcodeproj
```

3. `Config` 폴더의 설정 파일을 확인하고 필요한 환경 변수를 채웁니다.

4. 시뮬레이터 또는 실제 디바이스를 선택한 뒤 실행합니다.

## 8. 환경 설정

프로젝트 실행 전 아래 설정을 확인해야 합니다.

- `Config/Debug.xcconfig`
- `Config/Release.xcconfig`
- `Config/Secrets.example.xcconfig`

설정 항목 예시:
- Core Server Base URL
- Translate Server Base URL
- OAuth 관련 설정값
- JWT 인증에 필요한 키 또는 토큰 설정

로컬 실행 시에는 `Secrets.example.xcconfig`를 참고하여 실제 환경 파일을 구성하는 방식으로 사용하는 것을 권장합니다.

## 9. 향후 확장 계획

- Steam, 콘솔 등 외부 플랫폼 연동 강화
- 플레이 기록 기반 추천 기능 고도화
- 커뮤니티 기능 및 소셜 공유 확장
- 리뷰 품질 향상을 위한 신고 및 moderation 기능 강화
- 오프라인 캐싱 및 성능 최적화
- 다국어 지원 확대

## 10. 요약

GamePedia는 게임 탐색, 리뷰 작성, 라이브러리 관리, 번역 지원 기능을 하나의 앱 경험으로 통합한 iOS 서비스입니다.

UIKit, Combine, MVI, Coordinator, Clean Architecture를 기반으로 구조를 설계하여 유지보수성과 확장성을 높였으며, Core Server와 Translate Server를 통해 안정적인 데이터 처리와 사용자 경험을 제공합니다.
