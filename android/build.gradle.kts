// android/build.gradle.kts (project-level)

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Required so that the app module can apply the google-services plugin
        classpath("com.google.gms:google-services:4.4.3")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDirec: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDirec)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDirec.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
