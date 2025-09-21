// android/app/build.gradle.kts
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// ⚠️ Qui il rootProject è la cartella "android/"
// quindi il file giusto è "key.properties" (NON "android/key.properties")
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}

// AdMob App IDs (debug = test, release = produzione)
private const val admobTestAppId = "ca-app-pub-3940256099942544~3347511713"
private const val admobProdAppId = "ca-app-pub-1939059393159677~5464841712"

android {
    namespace = "com.maxxe.raidcalc"          // il tuo package definitivo
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.maxxe.raidcalc"  // idem
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            if (keystoreProperties.isNotEmpty()) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        getByName("debug") {
            // App ID di TEST AdMob
            manifestPlaceholders["admobAppId"] = admobTestAppId
            isMinifyEnabled = false
            isShrinkResources = false
        }
        getByName("release") {
            // App ID reale AdMob
            manifestPlaceholders["admobAppId"] = admobProdAppId
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions { jvmTarget = "11" }
}

flutter { source = "../.." }
