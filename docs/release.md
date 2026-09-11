# MAP v1.0.1 출시 실행

운영 앱은 NCP `api.mapservice.app`과 `mapservice.app`을 사용한다. 시험은 GCP와 기존 Firebase PoC를 유지한다. 이 문서의 명령은 산출물 준비 절차이며 계정·실기기·스토어 검증을 완료했다는 뜻이 아니다. 확인되지 않은 스토어 최고 빌드 번호, Apple 서명 접두사, 공개 연락주소는 추정하지 않는다.

## 빌드 출처와 번호

`release.yml`은 시험 빌드를 `develop`, 운영 빌드를 `master`에서 받는다. 시험 `iosbuild-*` 태그는 `develop` 이력, 운영 `v*` 태그는 `master` 이력에 포함되어야 하고 체크아웃 SHA와 태그 대상도 같아야 한다. 기능 브랜치에서는 일반 `ci.yml`로 컴파일·테스트를 확인하고 출시 빌드를 만들지 않는다.

버전 원본은 `pubspec.yaml`의 `1.0.1+1`이다. **`+1`은 스토어에서 확인한 업로드 번호가 아니다.** 서명 운영 빌드에는 `build_number`와 `store_max_build_number`가 모두 필요하다. 스토어 콘솔에서 최고 업로드 번호를 확인한 뒤 더 큰 새 번호를 예약한다. 신규 상품이고 업로드가 없음을 확인한 경우에만 최고 번호에 `0`을 사용한다.

같은 workflow 재실행에서는 `build_number + GITHUB_RUN_ATTEMPT - 1`을 사용한다. 예를 들어 최초 301, 두 번째 시도 302다. 다른 workflow 실행을 새로 시작할 때는 직전 업로드를 다시 확인하고 새 번호를 입력한다. 두 스토어를 같은 실행에서 빌드하면 둘 중 큰 최고 번호를 기준으로 사용한다. 태그 실행에는 입력란이 없으므로 `prod` 환경의 `RELEASE_BUILD_NUMBER`, `STORE_MAX_BUILD_NUMBER` 변수를 먼저 갱신한다. 기존 `v1.0.0` 태그·자산을 덮어쓰지 않는다.

## GitHub 환경과 서명

현재 workflow가 참조하는 환경 이름은 정확히 `test`, `prod`다. 별도의 `production` 환경은 자동으로 사용되지 않는다. `prod` 환경 변수는 다음 값이다.

```text
API_ALLOWED_ORIGINS=https://api.mapservice.app
APP_CONFIG_URL=https://mapservice.app/app_config.json
INVITE_LINK_ORIGIN=https://mapservice.app
PUBLIC_SITE_ORIGIN=https://mapservice.app
```

각 플랫폼에는 해당 제한이 적용된 `GOOGLE_MAPS_ANDROID_API_KEY` 또는 `GOOGLE_MAPS_IOS_API_KEY`만 주입한다. 서버 `.env`와 `APP_DOTENV_B64`를 앱에 넣지 않는다.

| 플랫폼 | 서명 입력 |
|---|---|
| Android secrets | `ANDROID_KEYSTORE_B64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS` |
| iOS secrets | `IOS_DISTRIBUTION_P12_B64`, `IOS_DISTRIBUTION_P12_PASSWORD`, `IOS_APP_STORE_PROFILE_B64` |
| iOS variables | `IOS_TEAM_ID`, `IOS_APP_ID_PREFIX`, `IOS_DISTRIBUTION_CERT_SHA1` |

`IOS_APP_ID_PREFIX`는 실제 프로필의 application-identifier 접두사다. Team ID와 같다고 추정하지 않는다. Apple 로그인 서버용 인증키는 이 배포 서명과 별개다.

Android는 운영 서명 APK와 AAB를 만들고 기존 인증서 지문을 대조한다. ONEconsole 기존 상품의 형식·서명을 확인한 뒤 맞는 파일을 올린다. Firebase testers 배포는 시험 환경에서 `distribute_android=true`를 별도로 선택한 경우에만 실행한다.

iOS는 **iPhone 전용**이다. `v1.0.1` 태그만으로 iOS 서명 IPA는 생성되지 않는다. `master` 또는 그 이력의 최종 `v1.0.1` 태그에서 다음 입력으로 수동 실행한다.

```text
app_environment=prod
build_android=false
signed_ios=true
build_number=<새로 예약한 번호>
store_max_build_number=<App Store Connect에서 확인한 최고 번호>
```

생성된 IPA는 Apple Transporter로 업로드한다. CI는 Apple에 업로드하지 않는다. App ID·배포 인증서·프로필·약관 처리가 끝나지 않았다면 서명·업로드 완료로 기록하지 않는다. artifact manifest에 소스 SHA·실행·버전·파일 해시·iOS SDK와 privacy inventory를 남긴다.

## NCP 공개 웹 준비

Flutter 웹 전체 빌드는 앱 등록용 정책·지원·초대 페이지에 필요하지 않다. `scripts/prepare-ncp-public.py`는 추적 중인 정책 5개와 초대 페이지를 복사하고 운영 `app_config.json`, `invite-environment.json`, Android App Links와 Apple Universal Links 파일을 생성한다. 기존 `hosting/`과 Firebase 파일은 수정하지 않는다.

공개 정책이 미완료인 현재는 먼저 초안을 만든다. Android 지문은 실제 설치 APK를 서명한 인증서의 SHA-256을 사용한다.

```bash
python3 scripts/prepare-ncp-public.py \
  --output-dir build/ncp-public-draft \
  --android-cert-sha256 "$MAP_RELEASE_CERT_SHA256"
```

실제 Apple 접두사가 준비되지 않았다면 AASA를 생성하지 않고 미완료로 기록한다. 모든 초안은 `DRAFT_NOT_SUBMITTABLE` 상태이며 정책에 초안 표시를 붙인다. Caddy 공개 단계는 이 상태를 거부한다. 출력 디렉터리는 새 경로여야 하며 기존 출력은 덮어쓰지 않는다.

최종 정책은 실제 NCP 운영·GCP 관리자 접근·유료 Gemini 처리·보존 및 삭제·위치정보 절차·공개 연락주소를 확인하여 별도 디렉터리에 완성한다. 시험 정책의 미확정 설명만 삭제하는 방식으로 완료 처리하지 않는다. 에이전트는 실제 운영 설정과 사용자가 지정한 공개 주소를 대조한 검토 결과를 다음 비공개 파일에 기록한다. 별도의 사용자 승인 단계를 추가하지 않는다.

```json
{
  "status": "REVIEWED_FOR_PRODUCTION",
  "public_contact_address": "<실제로 지정한 공개 연락주소>",
  "files": {
    "legal/privacy.html": "<검토한 파일의 SHA-256>",
    "legal/terms.html": "<검토한 파일의 SHA-256>",
    "legal/location-terms.html": "<검토한 파일의 SHA-256>",
    "legal/support.html": "<검토한 파일의 SHA-256>",
    "legal/delete-account.html": "<검토한 파일의 SHA-256>"
  }
}
```

이 검토 기록은 정확한 정책 바이트를 묶기 위한 것이며 법률 적합성 인증이 아니다. 깨끗한 `master` 체크아웃에서 실제 서명 메타데이터와 검토 파일을 입력한다.

```bash
python3 scripts/prepare-ncp-public.py --release \
  --output-dir build/ncp-public-release \
  --policy-directory "$MAP_FINAL_POLICY_DIRECTORY" \
  --policy-review "$MAP_POLICY_REVIEW_FILE" \
  --android-cert-sha256 "$MAP_RELEASE_CERT_SHA256" \
  --apple-app-id-prefix "$MAP_APP_ID_PREFIX"
```

결과 `public/`은 `/srv/map-prod/data/public`에, `manifest.json`은 공개 루트 밖 `/srv/map-prod/data/public-manifest.json`에 배치한다. `READY_FOR_PUBLICATION`, `blockers=[]`, 파일 전체 해시·운영 환경·서명 메타데이터를 NCP serving 도구가 검증한 뒤 공개한다. 이 상태는 정적 파일 준비 완료만 뜻하며 실기기·법률·스토어 승인 증거를 대신하지 않는다.

Caddy는 기존 정책 URL 별칭을 같은 HTML로 연결하고 `/invite/*`를 초대 페이지로 연결한다. JSON·AASA는 `application/json`, 앱 설정·초대 설정은 `no-store`, 정책은 `no-store`, `nosniff`, `no-referrer`를 적용한다. 알 수 없는 파일 경로를 Flutter SPA로 대체하지 않는다.

## 출시 전 확인

Python 회귀는 `python3 -m unittest discover -s scripts/tests -v`로 실행한다. 최종 서명 앱으로 실기기에서 로그인·위치 허용/거부·추천·Vision·초대·채팅·신고·탈퇴를 확인한다. 운영 주소와 HTTPS·WebSocket·정책·앱 링크를 실제 접속하여 검사한다. 서버와 스토어가 준비되지 않은 항목은 `NOT_RUN`으로 남긴다.
