import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is driven by android/key.properties (gitignored). When it is
// absent (fresh clone / CI without secrets) the release build falls back to the
// debug keys so `flutter run --release` still works — but such an APK is NOT
// publishable. For CI, base64 the .jks into a secret and write key.properties +
// the keystore in a build step.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.kyco.kyco_mobile"
    // flutter_secure_storage requires compileSdk 37 (backward-compatible bump
    // from the Flutter default of 36).
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.kyco.kyco_mobile"
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

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Release must be signed with the real keystore (android/key.properties,
            // gitignored). When it is absent we FAIL LOUDLY rather than silently
            // fall back to debug keys — a debug-signed AAB is rejected by the Play
            // Console and shipping one is worse than a broken build. Local dev that
            // needs an unpublishable release build (e.g. `flutter run --release`)
            // opts in with `-Pallow-debug-signing` (or ./gradlew … -PallowDebugSigning).
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else if (project.hasProperty("allowDebugSigning") || project.hasProperty("allow-debug-signing")) {
                signingConfigs.getByName("debug")
            } else {
                throw GradleException(
                    "key.properties missing — release signing not configured. " +
                    "Provide android/key.properties + the keystore, or pass " +
                    "-PallowDebugSigning for a local, NON-PUBLISHABLE debug-signed release build."
                )
            }
            // R8: shrink + obfuscate code and strip unused resources.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
