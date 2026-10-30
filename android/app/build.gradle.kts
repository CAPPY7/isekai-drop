plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.isujaykumar.isekaidrop"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // Compress native libraries inside the APK (keeps the arm64 APK under
    // 25 MB with the offline QR scanner). Android extracts them on install.
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.isujaykumar.isekaidrop"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // THROWAWAY DEVELOPMENT KEY (approved by the project owner, see AGENTS.md).
    // These passwords are deliberately NOT secret. This key is only for test
    // builds so every APK is signed the same way and updates install cleanly.
    // A real release key is created in the final phase and is never committed.
    //
    // RELEASE KEY (active since 0.11.1): CI (android.yml and
    // android-release.yml) sets these environment variables from GitHub
    // secrets. Local/debug builds don't have them and use the dev key.
    // See docs/RELEASE_SIGNING.md.
    val releaseStore = System.getenv("ISEKAI_RELEASE_KEYSTORE")
    val useReleaseKey = !releaseStore.isNullOrBlank()
    signingConfigs {
        create("dev") {
            storeFile = file("isekai-drop-dev.jks")
            storePassword = "isekai-drop-dev-only"
            keyAlias = "isekai-drop-dev"
            keyPassword = "isekai-drop-dev-only"
        }
        if (useReleaseKey) {
            create("release") {
                storeFile = file(releaseStore!!)
                storePassword = System.getenv("ISEKAI_RELEASE_STORE_PASSWORD")
                keyAlias = System.getenv("ISEKAI_RELEASE_KEY_ALIAS")
                keyPassword = System.getenv("ISEKAI_RELEASE_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (useReleaseKey) "release" else "dev")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
