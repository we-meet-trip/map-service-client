import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

// 지도 키가 담긴 설정 파일. 이 파일의 위치는 앱 루트(android 폴더의 한 단계
// 위)다. 한 단계를 더 올라가면 파일이 없어 키가 빈 값으로 들어가고, 그러면
// 빌드는 멀쩡히 끝나는데 실행할 때 지도만 인증에 실패한다.
val envProperties = Properties()
val envFile = rootProject.file("../.env")
if (envFile.exists()) {
    envFile.inputStream().use { envProperties.load(it) }
} else {
    logger.warn("WARNING: ${envFile.path} 부재 → 지도 클라이언트 식별자가 비어 있다.")
}

// 릴리스 서명 설정. key.properties 는 gitignore 되며 레포에 커밋되지 않는다.
// 설정 파일과 키스토어 실물이 모두 있어야 릴리스 키로 서명하고, 하나라도
// 없으면 debug 로 폴백한다(아래 buildTypes).
//
// 설정 파일만 보고 판단하면, 키스토어만 사라진 환경에서 서명 단계에 가서야
// 파일을 못 찾고 죽는다. 그 지점의 오류는 원인을 가리키지 않아 추적이 어렵다.
// 경로 해석은 아래 signingConfigs 와 같은 file() 을 써서, 상대경로가 적혀도
// 두 곳의 판정이 갈리지 않게 한다.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}
val keystoreFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
val hasReleaseSigning = keystoreFile != null && keystoreFile.exists()

val naverMapClientId = envProperties.getProperty("NAVER_MAP_CLIENT_ID")
    ?: localProperties.getProperty("naver.map.client.id")
    ?: ""

android {
    namespace = "kr.mapservice.client"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // 지도 SDK 인증은 이 식별자로 이뤄진다. 지도 콘솔에 이 이름이 등록돼
        // 있어야 지도가 뜬다 — 등록되지 않으면 401 로 타일이 비어 나온다.
        applicationId = "kr.mapservice.client"
        // minSdk 24: flutter_naver_map 1.4.4 요구 최소치(NCP Maps SDK).
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["naverMapClientId"] = naverMapClientId
        // 초대 링크를 받는 도메인. 이 도메인의 /.well-known/assetlinks.json 에
        // 아래 applicationId 와 릴리스 서명 지문이 올라가 있어야 링크가 앱으로
        // 열린다(그렇지 않으면 브라우저로만 열린다).
        manifestPlaceholders["deepLinkHost"] = "mapcenter-b59ca.web.app"
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // 설정 파일과 키스토어가 모두 있으면 릴리스 키로 서명(배포용). 배포
            // APK 는 항상 키를 보유한 빌드 머신에서 만든다. 릴리스를 요청한
            // 빌드에서 서명이 없으면 debug 키로 서명된 채 나가기 전에 여기서
            // 멈춘다. 그 외(로컬 개발)에는 debug 로 폴백한다.
            val releaseRequested = gradle.startParameter.taskNames.any {
                it.contains("Release", ignoreCase = true)
            }
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else if (releaseRequested) {
                throw GradleException(
                    "release 서명 설정(key.properties) 또는 키스토어 부재 — 배포 빌드를 중단한다"
                )
            } else {
                // 무조건 던지면 안 된다 — 설정 단계는 debug 빌드도 이 블록을 평가한다.
                logger.warn(
                    "WARNING: 서명 설정 또는 키스토어 부재 → release 를 debug 키로 서명(배포 금지)."
                )
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
