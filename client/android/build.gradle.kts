allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    
    // Apply lint configuration to all subprojects
    afterEvaluate {
        if (project.hasProperty("android")) {
            configure<com.android.build.gradle.BaseExtension> {
                lintOptions {
                    isAbortOnError = false
                    isIgnoreWarnings = true
                    isCheckReleaseBuilds = false
                    disable("MissingClass")
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

// Align Kotlin jvmTarget for modules that still build Java with 1.8
project(":receive_sharing_intent") {
    tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
        kotlinOptions {
            jvmTarget = "1.8"
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
