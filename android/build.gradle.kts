buildscript {
    repositories {
        google()
        mavenCentral()
        maven { url = java.net.URI("https://chaquo.com/maven") }
    }
    dependencies {
        classpath("com.android.tools.build:gradle:9.1.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.4.10")
        classpath("com.chaquo.python:gradle:17.0.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = java.net.URI("https://chaquo.com/maven") }
    }
}

// 1. OVERRIDE MUSS VOR evaluationDependsOn STEHEN
subprojects {
    afterEvaluate {
        if (hasProperty("android")) {
            extensions.configure<com.android.build.gradle.BaseExtension>("android") {
                compileSdkVersion(36)
            }
        }
    }
}

// 2. Build-Verzeichnis-Logik
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// 3. DAS ZWINGT GRADLE ZUR AUSWERTUNG - MUSS NACH DEM OVERRIDE STEHEN
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}