plugins {
    id("com.android.application") version "8.10.1" apply false
    kotlin("android") version "2.1.20" apply false
    kotlin("jvm") version "2.1.20" apply false
    kotlin("plugin.compose") version "2.1.20" apply false
    kotlin("plugin.serialization") version "2.1.20" apply false
}

allprojects {
    providers.gradleProperty("localBuildRoot").orNull?.let { directory ->
        layout.buildDirectory.set(file("$directory/${project.name}"))
    }
}