plugins { id("com.android.application"); id("kotlin-android"); id("dev.flutter.flutter-gradle-plugin") }
android { namespace = "com.cashier.lebanon.pro"; compileSdk = flutter.compileSdkVersion; ndkVersion = flutter.ndkVersion
 defaultConfig { applicationId = "com.cashier.lebanon.pro"; minSdk = 24; targetSdk = flutter.targetSdkVersion; versionCode = flutter.versionCode; versionName = flutter.versionName }
 buildTypes { release { signingConfig = signingConfigs.getByName("debug") } }
}
flutter { source = "../.." }
