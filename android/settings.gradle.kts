pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        // 阿里云镜像默认关：CI 的 runner 上它偶发 5xx，Gradle 会把该仓库禁掉并直接判定依赖
        // 不可解析（官方仓库排在后面也兜不住）。需要时用 `ALIYUN_MAVEN_MIRROR=1` 或
        // `-PaliyunMirror` 显式开。这个 `val` 只能待在 lambda 里 —— `pluginManagement`
        // 必须是 settings 文件的第一个块，脚本顶层声明会违反这条。
        val useAliyunMirror =
            providers.environmentVariable("ALIYUN_MAVEN_MIRROR").isPresent ||
                providers.gradleProperty("paliyunMirror").isPresent

        if (useAliyunMirror) {
            maven { setUrl("https://maven.aliyun.com/repository/central") }
            maven { setUrl("https://maven.aliyun.com/repository/jcenter") }
            maven { setUrl("https://maven.aliyun.com/repository/google") }
            maven { setUrl("https://maven.aliyun.com/repository/gradle-plugin") }
            maven { setUrl("https://maven.aliyun.com/repository/public") }
            maven { setUrl("https://maven.aliyun.com/nexus/content/groups/public/") }
            maven { setUrl("https://maven.aliyun.com/nexus/content/repositories/jcenter") }
        }
        maven { setUrl("https://maven.pkg.jetbrains.space/public/p/compose/dev") }
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // 下面两个版本与 Flutter 3.47.x 的 Android 模板保持一致，也是 flutter_tools
    // 的 maxKnownAgpVersionWithFullKotlinSupport / maxKnownAndSupportedKgpVersion 上限。
    // AGP 9.1.x 要求 Gradle >= 9.3.1（见 gradle/wrapper/gradle-wrapper.properties），JDK >= 17。
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
}

include(":app")
