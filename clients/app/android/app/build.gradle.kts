import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Real release signing key, kept out of git (see android/.gitignore) and
// supplied locally via key.properties or in CI by decoding the
// ANDROID_KEYSTORE_BASE64 secret (see .github/workflows/release.yml).
// Absent entirely for F-Droid's from-source build and for contributors
// without the key — those fall back to the debug signing config below.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "dev.librenotes.app"
    compileSdk = flutter.compileSdkVersion
    // Pinned to satisfy path_provider_android & sqlite3_flutter_libs, which
    // require a newer NDK than Flutter's default. NDKs are backward compatible.
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.librenotes.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Ship arm64 only: covers essentially all modern Android phones and
        // keeps the APK small. Drops armeabi-v7a, x86 and x86_64.
        ndk {
            abiFilters += "arm64-v8a"
        }
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Signed with the real release keystore when available (local
            // key.properties, or CI via the ANDROID_KEYSTORE_BASE64 secret).
            // F-Droid builds from source with no key.properties present, so
            // this falls back to debug there — harmless, since F-Droid
            // always re-signs with its own repo key regardless of what
            // signs this build. See CLAUDE.md "Licensing & distribution."
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
