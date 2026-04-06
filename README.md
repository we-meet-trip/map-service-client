# map-service-client

> MAP Mobile App (Flutter)

Flutter 기반 크로스 플랫폼 모바일 앱. 사용자가 여행 테마/분위기를 선택하면 AI 추천 결과를 받아 네이버 지도 위에 최적 경로를 표시한다.

## 기술 스택

| 항목 | 기술 |
|------|------|
| Framework | Flutter |
| Language | Dart |
| Map | 네이버 지도 SDK (`flutter_naver_map`) |
| State | Provider |
| IDE | Android Studio |
| Design | Figma |

## 디렉토리 구조 (예정)

```
map-service-client/
├── lib/
│   ├── main.dart
│   ├── screens/               # 화면 (홈, 태그선택, 추천결과, 상세 등)
│   ├── widgets/                # 재사용 위젯
│   ├── services/               # Spring Boot API 호출
│   ├── models/                 # 데이터 모델
│   └── providers/              # 상태 관리
├── android/
├── ios/
│   ├── Runner/Info.plist       # 위치 권한 설정
│   └── Podfile                 # iOS 최소 버전 13+
├── pubspec.yaml
├── .gitignore
├── LICENSE
└── README.md
```

## 실행 방법

### 사전 조건

- Flutter SDK 설치
- Android Studio 또는 Xcode
- 백엔드 실행 중 (Docker Compose — [map-service-user](https://github.com/we-meet-trip/map-service-user) 참고)

### 실행

```bash
flutter pub get
flutter run
```

## 타겟 플랫폼

| 항목 | Android | iOS |
|------|---------|-----|
| 최소 버전 | API 21 (5.0) | iOS 13+ |
| 빌드 도구 | Android Studio | Xcode (Mac 필수) |
| PoC 시연 | 에뮬레이터 또는 실기기 APK | 시뮬레이터 |

## 주요 화면 (예정)

| 화면 | 기능 |
|------|------|
| 온보딩 | 선호 모빌리티, 테마 태그 초기 선택 |
| 홈 | 현재 위치 기반 추천 진입, 날씨 표시 |
| 태그 선택 | 테마/분위기/활동 태그 다중 선택 + 자유 텍스트 입력 |
| 추천 결과 | 네이버 지도 위 경로 표시, 장소 카드 리스트 |
| 장소 상세 | 장소 정보, 리뷰 요약, 태그, 실내/실외 표시 |
| 경로 저장 | 추천 경로 저장 및 재조회 |
| 즐겨찾기 | 관심 장소 목록 |
| 마이페이지 | 프로필, 선호 설정 수정, 저장 경로 목록 |

## License

MIT
