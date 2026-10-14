plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Codemagic sets these when Android code signing is enabled for the workflow
// (codemagic.yaml: android_signing). With them, every build is signed with the
// same key, so a new APK installs over the old one. Without them (your laptop,
// or before you upload a keystore) release builds use the debug key.
val cmKeystorePath: String? = System.getenv("CM_KEYSTORE_PATH")

android {
    namespace = "com.portalai.portal_ai"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications needs desugaring (Build Guide 4.4)
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // Must match package_name in android/app/google-services.json
        applicationId = "com.portalai.portal_ai"
        // Firebase needs Android 7.0 (API 24) or newer (Build Guide 4.4)
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (cmKeystorePath != null) {
            create("release") {
                storeFile = file(cmKeystorePath)
                storePassword = System.getenv("CM_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("CM_KEY_ALIAS")
                keyPassword = System.getenv("CM_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (cmKeystorePath != null)
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// google-services.json comes from Firebase console -> Project settings -> Your
// apps -> com.portalai.portal_ai. Codemagic writes it from GOOGLE_SERVICES_B64.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}
