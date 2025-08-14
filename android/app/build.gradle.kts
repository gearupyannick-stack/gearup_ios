// android/app/build.gradle.kts

val flutterVersionCode: String = "2" // Replace with your actual version code
val flutterVersionName: String = "1.0.1" // Replace with your actual version name

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.gearup.app"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.gearup.app"
        minSdk = 23
        targetSdk = 35
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
    }

    signingConfigs {
        // Replace the path below with the absolute path to your keystore,
        // or place the keystore file in the android/app directory and use:
        // storeFile = file("my-upload-key.keystore")
        create("release") {
            storeFile = file("/home/yannick/Documents/gearup/dev/gearup/my-upload-key.keystore")
            storePassword = "Gearup200125"
            keyAlias = "my-upload-key"
            keyPassword = "Gearup200125"
        }
    }

    buildTypes {
        getByName("release") {
            // Enable both code and resource shrinking
            isMinifyEnabled   = true
            isShrinkResources = true

            signingConfig = signingConfigs.getByName("release")

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
    kotlinOptions {
        jvmTarget = "11"
    }
}

flutter {
    source = "../.."
}

configurations {
    all {
        exclude(group = "com.google.android.gms", module = "play-services-measurement")
    }
}

dependencies {
    // Firebase BOM
    implementation(platform("com.google.firebase:firebase-bom:32.8.0"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-storage")

    // AdMob & aligned measurement libs
    implementation("com.google.android.gms:play-services-ads:23.0.0")
    implementation("com.google.android.gms:play-services-measurement:23.0.0")
    implementation("com.google.android.gms:play-services-measurement-base:23.0.0")
    implementation("com.google.android.gms:play-services-measurement-impl:23.0.0")
    implementation("com.google.android.gms:play-services-measurement-api:23.0.0")
    implementation("com.google.android.gms:play-services-measurement-sdk-api:23.0.0")

    // AndroidX & Material
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("com.google.android.material:material:1.9.0")
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")
    implementation("androidx.browser:browser:1.8.0")
    implementation("androidx.webkit:webkit:1.14.0")
    implementation("androidx.window:window:1.2.0")
    implementation("androidx.activity:activity-ktx:1.8.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")

    // If you need multidex:
    // implementation("androidx.multidex:multidex:2.0.1")
}
