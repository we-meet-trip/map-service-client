# Google Maps 클라이언트 설정

Android·iOS·웹 지도는 `google_maps_flutter`의 실제 Google SDK를 사용한다.
키가 없거나 웹 SDK 인증에 실패하면 오류 화면을 표시하며 임의 타일로 대체하지 않는다.
지도·마커·이동경로·행정구역·카메라·위치 표시는 `lib/core/maps`에서 변환한다.
Google SDK의 로고와 출처 표시는 유지하며, 하단 시트 여백은 SDK padding에 전달한다.

서버용 Google 키를 앱에 복사하지 않는다. 클라이언트 키는 앱 바이너리/웹에서
확인할 수 있으므로 각 플랫폼과 필요한 API로 제한한 별도 키를 사용한다.

| 대상 | 빌드 define | 제한 |
|---|---|---|
| Android | `GOOGLE_MAPS_ANDROID_API_KEY` | Maps SDK for Android, 패키지 `kr.mapservice.client`와 실제 서명 인증서 SHA-1 |
| iOS | `GOOGLE_MAPS_IOS_API_KEY` | Maps SDK for iOS, 실제 Release Bundle ID |
| 웹 | `GOOGLE_MAPS_WEB_API_KEY` | Maps JavaScript API, 허용한 HTTPS 웹 referrer와 필요한 개발 localhost만 |

각 API 활성화·결제 연결·쿼터를 프로젝트에서 확인한다. Android는 API 24 이상,
iOS는 14 이상이다. Android debug와 Play App Signing 인증서가 다르면 각각 등록한다.
iOS의 Apple 로그인 entitlement와 서명 설정은 지도 설정과 별개로 유지한다.

키 값은 저장소 밖의 플랫폼별 JSON 파일에서 `--dart-define-from-file`로 전달한다.
파일에는 해당 플랫폼 키 하나만 넣는다. 서버 토큰·개인키·백업 자격증명을 넣지 않는다.

```sh
flutter build appbundle --dart-define-from-file=/private/config/maps-android.json
flutter build ipa --dart-define-from-file=/private/config/maps-ios.json
flutter build web --dart-define-from-file=/private/config/maps-web.json
```

Android Gradle이 Flutter의 `dart-defines`를 읽어 manifest의 `com.google.android.geo.API_KEY`에
전달한다. iOS는 Info.plist의 `MapsDartDefines`에서 iOS 키만 추출해 AppDelegate에서
`GMSServices.provideAPIKey`를 호출한다. 웹은 앱 초기화 때 Google JS SDK를 한 번 로드한다.
`.env`에 담긴 과거 지도 식별자나 서버용 일반 Google 키를 fallback으로 읽지 않는다.

실기기/브라우저 인수 검증은 제한된 키로 지도6화면을 열어 타일·출처 표시, 실제장소
마커 탭, 도로 경로, 경계 폴리곤, 확대·축소·fit bounds, 위치/방향 갱신, 모달 중 제스처
차단을 확인한다. 키없는 빌드의 오류 화면이나 단위검사 성공은 SDK 인증 성공 증거가 아니다.

근거: [Flutter Google Maps](https://pub.dev/packages/google_maps_flutter),
[Google 키 보안 가이드](https://developers.google.com/maps/api-security-best-practices).

## 릴리스 설정과 컴파일 검사

`release.yml` 수동 실행은 `app_environment=test`, `signed_android=false`가 기본이다.
이 경로는 Android debug 컴파일만 확인하며 테스터 배포를 실행하지 않는다.
`iosbuild-*`와 `build_ios=true`는 iOS `--no-codesign` 컴파일 검사다. 키 없는 컴파일을
허용하므로 이 결과만으로 지도 렌더나 플랫폼 인증 성공을 선언하지 않는다.

`vMAJOR.MINOR.PATCH` 태그는 `prod` GitHub Environment를 사용한다. 해당 환경에
`API_ALLOWED_ORIGINS`(HTTPS API origin의 쉼표 목록)와 `APP_CONFIG_URL`(HTTPS 설정 파일 URL)을
명시해야 한다. 운영 설정이 없거나 GCP 테스트 주소를 가리키면 중단한다. `test` 환경은
현재 GCP 테스트 주소와 테스트 설정 파일이 기본이며 환경 변수로 명시할 수도 있다.
각 GitHub Environment의 변수와 보호 규칙은 실제 배포 전에 별도로 확인한다.

Google 키는 해당 환경의 `GOOGLE_MAPS_ANDROID_API_KEY` / `GOOGLE_MAPS_IOS_API_KEY` secret으로
주입한다. 서명된 설치본에는 해당 플랫폼 키가 필수다. 현재 iOS 워크플로에는 스토어 서명·
배포 단계가 없으며, 이를 추가할 때 `mobile-release-config.py --signed --platform ios` 검사를
반드시 사용한다. 서버용 Google Places 키와 `APP_DOTENV_B64`는 릴리스 입력으로 사용하지 않는다.

`scripts/mobile-release-config.py`가 허용한 설정만 임시 JSON(0600)에 기록한다. `.env`는 앱 자산에서 제외하며
기존 로컬 파일은 수정하지 않는다. Android/iOS 빌드는 각각 다른 JSON을 `--dart-define-from-file`로 받는다.
버전명은 숫자 세 부분으로, 빌드 번호는 양의 정수로 제한하며 워크플로는 인자를 인용해 전달한다.
같은 태그의 GitHub 릴리스 파일을 다시 올릴 때 기존 파일을 덮어쓰지 않는다.

설정 검증: `python3 -m unittest discover -s scripts/tests -v`.
위의 수동 `flutter build` 예시는 지도 키 전달 형식만 보이며, 정식 빌드에서는 동일 JSON에
`APP_ENV`, `API_ALLOWED_ORIGINS`, `APP_CONFIG_URL`도 포함해야 한다.

앱에서 `flutter_dotenv`와 `.env` 자산을 제거했으므로 로컬 빌드도 서버 키를 포함하지 않는다.
Vision 개발 서버 변경은 debug 빌드의 `--dart-define=VISION_SERVER_HOST=host:port`만 사용한다.
