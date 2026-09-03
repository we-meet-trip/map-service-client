# 초대 링크가 앱을 여는 구조

대화방 초대 링크를 눌렀을 때 브라우저가 아니라 앱이 뜨게 하는 설정이다.
안드로이드는 도메인 쪽에 앱 서명 지문을 올려 두어야 성립하고, iOS 는 애플
계정이 정해진 뒤에야 같은 방식을 쓸 수 있다.

## 현재 값

| 항목 | 값 | 정하는 곳 |
|---|---|---|
| 도메인 | `mapcenter-b59ca.web.app` | `android/app/build.gradle.kts` 의 `deepLinkHost` |
| 패키지 | `kr.mapservice.client` | 같은 파일의 `applicationId`, iOS 는 `PRODUCT_BUNDLE_IDENTIFIER` |
| 서명 지문 | `F7:49:F8:9D:94:5A:62:71:70:A7:9D:01:D7:C0:8A:0E:BF:67:DF:AA:97:E8:02:1A:66:CE:49:11:89:16:68:39` | 배포용 키스토어 |
| 초대 주소 생성 | `https://mapcenter-b59ca.web.app/invite/{토큰}` | 서버(BFF)의 `chat.invite-base-url` |

세 값은 서로 맞아야 한다. 하나라도 어긋나면 검증이 조용히 실패하고, 링크는
앱 대신 브라우저로 열린다.

## 안드로이드

`hosting/.well-known/assetlinks.json` 에 패키지와 지문이 들어 있다. 이 파일은
호스팅에 올리는 디렉터리에 직접 두며, 웹 빌드가 덮어쓰지 않는다(`tool/build_web.sh`
가 `.well-known/` 을 제외한다). 빌드 산출물에 실어 보내려다 매번 사라지는 일을
막으려고 그렇게 해 두었다.

```bash
bash tool/build_web.sh           # 맨 flutter build web 은 서버 키가 새어 나간다
firebase deploy --only hosting
curl -s https://mapcenter-b59ca.web.app/.well-known/assetlinks.json
```

매니페스트의 초대용 인텐트 필터에는 자동 검증이 켜져 있다. 설치된 기기에서
검증 상태를 본다:

```bash
adb shell pm get-app-links kr.mapservice.client
```

`verified` 가 나오면 링크가 앱으로 열린다. 디버그 키로 만든 빌드는 지문이
달라 검증에 실패하는데, 이때는 링크가 브라우저로 열릴 뿐 동작이 깨지지는
않는다. 배포용 키로 서명된 설치본에서만 확인할 수 있다.

## 앱 전용 주소

웹 주소와 별개로 `mapservice://invite/...` 로도 같은 화면을 연다. 도메인
검증이 필요 없어 개발 중 확인에 쓰고, iOS 에서는 유일하게 동작하는 길이다.
안드로이드는 매니페스트, iOS 는 `ios/Runner/Info.plist` 의 `CFBundleURLTypes`,
앱 안에서는 `lib/core/services/deep_link_service.dart` 가 같은 이름을 본다.
**셋 중 하나만 달라도 그 기기에서만 링크가 조용히 무시된다.**

```bash
adb shell am start -a android.intent.action.VIEW -d "mapservice://invite/테스트토큰"
```

## iOS

웹 주소로 온 링크를 앱이 받으려면 애플 쪽 도메인 소유 확인(Universal Links)이
필요하고, 그것은 유료 개발자 계정을 전제한다. 계정이 정해지기 전까지 iOS 는
앱 전용 주소(`mapservice://`)만 동작한다.

계정이 생긴 뒤 할 일:

1. 개발자 계정에서 앱 식별자에 Associated Domains 를 켠다.
2. Xcode 의 Runner 대상에 `applinks:mapcenter-b59ca.web.app` 을 추가한다.
3. `hosting/.well-known/apple-app-site-association` 을 만들어 `/invite/*` 경로를
   앱 식별자(`<팀ID>.kr.mapservice.client`)에 연결하고 배포한다.
   확장자 없이, `application/json` 으로 서빙되어야 한다.

## 브라우저로 열렸을 때

앱 링크 검증이 통과한 안드로이드 기기는 이 과정을 거치지 않고 앱이 바로 뜬다.
브라우저까지 오는 경우는 앱이 없거나, iOS 이거나, 앱 안의 브라우저로 열렸을 때다.

`hosting/invite/index.html` 이 그 자리를 받는다(`firebase.json` 의 `/invite/**`
재작성). 이 페이지는 무인증 미리보기로 방 정보를 그 자리에서 보여 주고, 안드로이드
에서는 `intent:` 주소로 앱을 연다 — 카카오톡 안의 브라우저에서 밖으로 나갈 수 있는
거의 유일한 길이다. iOS 의 앱 내 브라우저는 앱을 여는 수단 자체가 없어서, 그 경우
이 페이지가 보여 주는 정보가 사용자가 받을 수 있는 전부다.
