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
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
