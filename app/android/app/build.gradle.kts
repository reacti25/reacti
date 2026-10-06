import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Staging build: the same code installed as a second app beside production
// (com.reacti.app.staging, "Reacti Staging", orange-band icon), talking to the
// staging Firebase app (Android plan, Step 2). Mirrors iOS's FlavorOverride: off
// by default, so a plain `flutter run` / `flutter build` is the production app.
// Switch it on with the environment variable ORG_GRADLE_PROJECT_reactiStaging=true
// (Gradle turns ORG_GRADLE_PROJECT_* into project properties), together with
// --dart-define=ANALYTICS_ENV=staging so Dart picks the matching Firebase app.
val reactiStaging = (project.findProperty("reactiStaging") as String?) == "true"

// Release signing with the Play upload key (Android plan, Step 4a). CI writes
// android/key.properties and the keystore from the ANDROID_UPLOAD_KEYSTORE_*
// secrets; both are gitignored. Without them (a local machine, a Dependabot
// PR) release builds fall back to the debug key, so `flutter run --release`
// still works. The upload key's owner copy lives in .local-secrets/android/.
val uploadKey = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

android {
    namespace = "com.reacti.app"
    compileSdk = 36
    ndkVersion = "29.0.13599879"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = if (reactiStaging) "com.reacti.app.staging" else "com.reacti.app"
        manifestPlaceholders += mapOf(
            "appLabel" to if (reactiStaging) "Reacti Staging" else "Reacti",
            "appIcon" to if (reactiStaging) "@mipmap/ic_launcher_staging" else "@mipmap/ic_launcher",
        )
        // Pinned, not inherited from the Flutter plugin, so a Flutter downgrade
        // cannot silently drop below Play's requirement (targetSdk 36 for new
        // apps and updates from 2026-08-31).
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (!uploadKey.isEmpty) {
            create("release") {
                storeFile = rootProject.file(uploadKey.getProperty("storeFile"))
                storePassword = uploadKey.getProperty("storePassword")
                keyAlias = uploadKey.getProperty("keyAlias")
                // PKCS12 keystores use the store password for the key as well.
                keyPassword = uploadKey.getProperty("storePassword")
                storeType = "pkcs12"
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}


dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
