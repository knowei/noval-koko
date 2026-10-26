allprojects {
    repositories {
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

// flutter_js 等第三方插件默认把 Kotlin 编译到 JVM 1.8，而 AGP 侧是 11/17；
// 新版 Gradle 要求两者一致，否则直接失败（Inconsistent JVM Target Compatibility）。
// 在所有模块评估完成后，把 Kotlin 任务的 jvmTarget 对齐到同模块的 Java target。
gradle.projectsEvaluated {
    subprojects {
        val androidExt =
            extensions.findByName("android") as? com.android.build.gradle.BaseExtension
        val javaTarget = androidExt?.compileOptions?.targetCompatibility?.toString()
        if (javaTarget == null) {
            return@subprojects
        }
        tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java)
            .configureEach {
                compilerOptions {
                    jvmTarget.set(
                        org.jetbrains.kotlin.gradle.dsl.JvmTarget.fromTarget(javaTarget)
                    )
                }
            }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
