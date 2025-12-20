plugins {
    id("com.android.application")
    id("kotlin-android")
    // تم إضافة السطر التالي لربط Firebase
    id("com.google.gms.google-services")
    // الـ Flutter Gradle Plugin يجب أن يكون الأخير
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.aksab_driver"
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
        // الـ ID الجديد الخاص بتطبيق المندوب
        applicationId = "com.example.aksab_driver"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // الإعدادات الافتراضية للـ Debug حالياً حتى مرحلة الرفع
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
