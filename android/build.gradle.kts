// 阿里云镜像**默认不启用**：GitHub 的 runner 上它偶发 5xx，而 Gradle 一旦遇到首个仓库报错就
// 把该仓库禁掉、直接判定依赖不可解析 —— 官方仓库排在后面也兜不住，`assembleDebug` 随之失败
// （CI 的 integration-test 就是这么红的）。国内本地要加速时显式开：
// `ALIYUN_MAVEN_MIRROR=1` 或 `-PaliyunMirror`。
val useAliyunMirror =
    providers.environmentVariable("ALIYUN_MAVEN_MIRROR").isPresent ||
        providers.gradleProperty("paliyunMirror").isPresent

allprojects {
    repositories {
        // 镜像必须排在官方仓库之前才有意义，所以整体开/关，不做「官方在前」的混合。
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
        gradlePluginPortal()
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
