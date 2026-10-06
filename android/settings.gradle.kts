pluginManagement {
    repositories { gradlePluginPortal(); mavenCentral(); google() }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories { mavenCentral(); google() }
}
rootProject.name = "StockChefAndroid"
include(":core")
if (providers.gradleProperty("coreOnly").orNull != "true") include(":app")