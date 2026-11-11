import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 正式签名（M6.1）：android/key.properties 由本地维护，不入版本库；
// 文件缺失时回退 debug 签名，保证他人 clone 后仍可直接构建。
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) FileInputStream(f).use { load(it) }
}

android {
    namespace = "com.dreamflow.dreamflow"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications 要求 core library desugaring
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.dreamflow.dreamflow"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Flutter 默认 21；M13 接 Health Connect 后必须 26（Android 8.0）——
        // 客户端库的清单里写死了 minSdk 26，强行 override 会在低版本上运行时炸
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystoreProperties["storeFile"] != null) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // 有 key.properties 走正式签名，否则回退 debug（仅用于开发自测）
            signingConfig = if (keystoreProperties["storeFile"] != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
    // M9 相册选图：读照片的 EXIF 旋转角（BitmapFactory 不解 EXIF，不转会躺下）
    implementation("androidx.exifinterface:exifinterface:1.3.7")
    // M13 健康数据：只读睡眠分期（手环 → 厂商 App → 健康库 → 这里）
    implementation("androidx.health.connect:connect-client:1.1.0")
    // Health Connect 的 readRecords / getGrantedPermissions 都是 suspend，
    // 原生侧用 runBlocking 在后台线程里调用（FlutterActivity 没有协程作用域）
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    // 授权流程用的是 ActivityResultContract（connect-client 只把它当实现依赖，
    // 不暴露给我们编译期），这里显式补上
    implementation("androidx.activity:activity:1.8.2")
}
