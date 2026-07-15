allprojects {
    repositories {
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        google()
        mavenCentral()
    }
}

subprojects {
    afterEvaluate {
        val hasAndroidPlugin = plugins.hasPlugin("com.android.library") || plugins.hasPlugin("com.android.application")
        if (hasAndroidPlugin) {
            try {
                val androidExt = extensions.getByName("android")
                val nsMethod = androidExt.javaClass.getMethod("getNamespace")
                val currentNs = nsMethod.invoke(androidExt) as String?
                if (currentNs == null || currentNs.isEmpty()) {
                    val setNsMethod = androidExt.javaClass.getMethod("setNamespace", String::class.java)
                    val ns = when (project.name) {
                        "isar_flutter_libs" -> "dev.isar.isar_flutter_libs"
                        "jni" -> "dev.isar.isar_flutter_libs.jni"
                        else -> "com.example.${project.name.replace("-", ".")}"
                    }
                    setNsMethod.invoke(androidExt, ns)
                }
                try {
                    val setCompileSdkMethod = androidExt.javaClass.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
                    setCompileSdkMethod.invoke(androidExt, 36)
                } catch (_: Exception) {
                }
                try {
                    val setNdkMethod = androidExt.javaClass.getMethod("setNdkVersion", String::class.java)
                    setNdkMethod.invoke(androidExt, "28.0.13004108")
                } catch (_: Exception) {
                }
            } catch (_: Exception) {
            }
        }
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
