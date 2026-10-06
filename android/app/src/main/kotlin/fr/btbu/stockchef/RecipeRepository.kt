package fr.btbu.stockchef

import android.content.Context
import android.util.AtomicFile
import fr.btbu.stockchef.core.*
import java.io.ByteArrayOutputStream
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

class RecipeRepository(context: Context, cacheName: String = "recipes-v1.json", private val fetch: () -> String = ::download) {
    private val cache = AtomicFile(File(context.filesDir, cacheName))
    fun cached(): List<Recipe> = runCatching {
        require(cache.baseFile.length() <= RecipeFeedCodec.MAX_BYTES)
        RecipeFeedCodec.decode(cache.readFully().toString(Charsets.UTF_8))
    }.getOrDefault(RecipeCatalog.recipes)

    fun refresh(): List<Recipe> {
        val text = fetch()
        val recipes = RecipeFeedCodec.decode(text)
        val output = cache.startWrite()
        try { output.write(text.toByteArray(Charsets.UTF_8)); cache.finishWrite(output) }
        catch (error: Exception) { cache.failWrite(output); throw error }
        return recipes
    }

    companion object {
        const val ENDPOINT = "https://btbu.aurelienleleu.fr/stockchef/recipes.json"
        private fun download(): String {
            val connection = URL(ENDPOINT).openConnection() as HttpURLConnection
            try {
                connection.connectTimeout = 5000
                connection.readTimeout = 5000
                connection.instanceFollowRedirects = false
                connection.setRequestProperty("Accept", "application/json")
                require(connection.responseCode == 200) { "Catalogue indisponible." }
                require(connection.contentLengthLong <= RecipeFeedCodec.MAX_BYTES)
                return connection.inputStream.use { input ->
                    val output = ByteArrayOutputStream()
                    val buffer = ByteArray(8192)
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        require(output.size() + count <= RecipeFeedCodec.MAX_BYTES)
                        output.write(buffer, 0, count)
                    }
                    output.toString("UTF-8")
                }
            } finally { connection.disconnect() }
        }
    }
}