allprojects {
    repositories {
        google()
        mavenCentral()
    }

    configurations.all {
        resolutionStrategy {
            force("com.tencent.liteav:LiteAVSDK_Professional:12.9.0.19478")
            force("com.tencent.liteav:LiteAVSDK_ScreenCapture:12.9.0.19478")
            force("io.trtc.uikit:rtc_room_engine:3.6.2.106")
            force("io.trtc.uikit:common:3.2.0.1016")
        }
    }
}

extra["liteavSdk"] = "com.tencent.liteav:LiteAVSDK_Professional:12.9.0.19478"
extra["roomEngineSdk"] = "io.trtc.uikit:rtc_room_engine:3.6.2.106"

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
