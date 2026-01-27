import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.gradle.api.tasks.compile.JavaCompile

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Ensure Kotlin compilation produces a JVM target compatible with Java compilation

subprojects {
    tasks.withType<KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
        }
    }

    // Try to set Java compilation target; tasks may be created later by Android plugin so also apply in projectsEvaluated
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
    }
}

// Enforce targets after all projects are evaluated (covers plugin-created tasks)
gradle.projectsEvaluated {
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
    }

    tasks.withType<KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
        }
    }

    // Some third-party plugins (e.g., beacon_broadcast) still compile Java with 1.8.
    // If an included project uses Java 1.8, match Kotlin to 1.8 for that project to avoid validation errors.
    rootProject.subprojects.filter { it.name == "beacon_broadcast" }.forEach { p ->
        p.tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = JavaVersion.VERSION_1_8.toString()
            targetCompatibility = JavaVersion.VERSION_1_8.toString()
        }
        p.tasks.withType<KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(JvmTarget.JVM_1_8)
            }
        }

        // Ensure this plugin compiles against the same (newer) Android API level as the app
        try {
            p.plugins.withType(com.android.build.gradle.LibraryPlugin::class.java) {
                p.extensions.configure<com.android.build.gradle.LibraryExtension>("android") {
                    compileSdk = 36
                }
            }
        } catch (_: Throwable) {}
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
