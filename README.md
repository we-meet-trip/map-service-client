# map-service-client

## 개요
MAP 서비스의 프론트엔드(Flutter) 클라이언트 레포지토리. 모바일(Android/iOS) 앱을 담당한다.

## 기술 스택
- Flutter / Dart
- 상태관리: Provider (예정)
- 지도: flutter_naver_map (예정)
- 플랫폼: Android (API 21+), iOS (13+)

## 디렉토리 구조
초기 셋업 단계 — 추후 추가 예정.

```
.
├── .github/
│   ├── ISSUE_TEMPLATE/
│   └── pull_request_template.md
├── .gitignore
├── LICENSE
└── README.md
```

진행 중인 구조 정의는 `develop` 브랜치 참고.

## 시작하기
추후 추가 예정 (`pubspec.yaml` 작성 후).

```
flutter pub get
flutter run
```

## 환경변수
`.env.example` 추가 시 갱신 예정. 백엔드 베이스 URL, 지도 API 키 등.

## 관련 레포
- [map-service-agent](https://github.com/we-meet-trip/map-service-agent) — FastAPI AI 에이전트 백엔드
- [map-service-user](https://github.com/we-meet-trip/map-service-user) — Spring Boot 사용자/인증 백엔드
- [map-service-client](https://github.com/we-meet-trip/map-service-client) — 본 레포 (Flutter 클라이언트)
- [map-service-info](https://github.com/we-meet-trip/map-service-info) — 아키텍처 및 공통 문서
