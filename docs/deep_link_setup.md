# Android App Links (딥링크) 설정 가이드

초대 링크(`https://{도메인}/invite/{token}`)를 탭했을 때 앱이 자동으로 열리게 하려면  
도메인에 `assetlinks.json`을 배포해야 합니다.

---

## 1. 도메인 설정

`android/app/build.gradle.kts` 파일에서 `deepLinkHost` 값을 실제 도메인으로 교체합니다.

```kotlin
manifestPlaceholders["deepLinkHost"] = "myapp.web.app" // 실제 도메인으로 교체
```

---

## 2. SHA-256 지문 추출

### 디버그 키 (개발용)

```bash
keytool -list -v \
  -keystore ~/.android/debug.keystore \
  -alias androiddebugkey \
  -storepass android \
  -keypass android
```

출력 중 `SHA256:` 항목의 값을 복사합니다.

### 릴리즈 키 (배포용)

```bash
keytool -list -v \
  -keystore <릴리즈_키스토어_경로> \
  -alias <alias명>
```

---

## 3. assetlinks.json 작성

아래 템플릿에 패키지명과 SHA-256 지문을 채워 넣습니다.

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.example.map_service_client",
      "sha256_cert_fingerprints": [
        "AA:BB:CC:DD:..."
      ]
    }
  }
]
```

---

## 4. 파일 호스팅

작성한 `assetlinks.json`을 도메인의 다음 경로에 업로드합니다.

```
https://{도메인}/.well-known/assetlinks.json
```

파일은 반드시 `Content-Type: application/json`으로 서빙되어야 합니다.

---

## 5. 검증

앱을 설치한 기기에서 아래 명령어로 App Links 검증 상태를 확인합니다.

```bash
adb shell pm get-app-links com.example.map_service_client
```

`STATUS: verified` 가 출력되면 정상입니다.
