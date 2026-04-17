import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Loads signing properties from android/key.properties (do NOT commit that file).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

val revenueCatApiKey: String =
    (
        keystoreProperties.getProperty("revenueCatApiKey")
            ?: providers.gradleProperty("RC_ANDROID_API_KEY").orNull
            ?: System.getenv("RC_ANDROID_API_KEY")
            ?: ""
        ).trim()

val isReleaseTaskRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
if (isReleaseTaskRequested && revenueCatApiKey.isBlank()) {
    throw GradleException(
        "Missing RevenueCat Android API key for release build. " +
            "Set 'revenueCatApiKey' in android/key.properties " +
            "or pass -PRC_ANDROID_API_KEY / RC_ANDROID_API_KEY."
    )
}

android {
    // IMPORTANT: this MUST be your final package id for Play Store.
    // If you change it after publishing, it's a different app.
    namespace = "com.maxxetto.raid_calc"

    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // IMPORTANT: must match Play Console applicationId.
        applicationId = "com.maxxetto.raid_calc"

        // RevenueCat UI requires Android minSdk 24.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Used by MainActivity bootstrap channel when --dart-define is omitted.
        manifestPlaceholders["revenuecatApiKey"] = revenueCatApiKey
    }

    signingConfigs {
        // Release signing uses android/key.properties + android/app/upload-keystore.jks
        create("release") {
            if (!keystorePropertiesFile.exists()) {
                throw GradleException(
                    "Missing android/key.properties. Create it to build a signed release."
                )
            }

            val storeFileName = keystoreProperties.getProperty("storeFile")
                ?: throw GradleException("key.properties: missing 'storeFile'")
            val storePassword = keystoreProperties.getProperty("storePassword")
                ?: throw GradleException("key.properties: missing 'storePassword'")
            val keyAlias = keystoreProperties.getProperty("keyAlias")
                ?: throw GradleException("key.properties: missing 'keyAlias'")
            val keyPassword = keystoreProperties.getProperty("keyPassword")
                ?: throw GradleException("key.properties: missing 'keyPassword'")

            // key.properties lives in android/, keystore lives in android/app/
            storeFile = file("$storeFileName")
            this.storePassword = storePassword
            this.keyAlias = keyAlias
            this.keyPassword = keyPassword
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }

        // Debug remains debug-signed by default.
        getByName("debug") {
            // keep defaults
        }
    }
}

flutter {
    source = "../.."
}
