plugins { kotlin("jvm"); kotlin("plugin.serialization") }
kotlin { jvmToolchain(17) }
tasks.test {
    val feed = rootProject.file("../../WebSite/src/stockchef/recipes.json")
    if (feed.exists()) { inputs.file(feed); systemProperty("stockchef.recipeFeed", feed.absolutePath) }
}
dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.8.1")
    testImplementation(kotlin("test-junit"))
}