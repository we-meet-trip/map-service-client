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

val envProperties = Properties()
val envFile = rootProject.file("../../.env")
if (envFile.exists()) {
    envFile.inputStream().use { envProperties.load(it) }
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
            // APK 는 항상 키를 보유한 빌드 머신에서 만든다. 둘 중 하나라도 없으면
            // debug 로 폴백(로컬 개발 편의) — 이 경우 서명 검증에서 debug 인증서로
            // 드러나므로 실수 배포를 막을 수 있다.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
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
