package fr.btbu.stockchef

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import fr.btbu.stockchef.core.*
import kotlinx.serialization.encodeToString

class StockDatabase(context: Context, name: String = "stockchef.sqlite") : SQLiteOpenHelper(context, name, null, 1) {
    override fun onCreate(database: SQLiteDatabase) {
        database.execSQL("CREATE TABLE state (id INTEGER PRIMARY KEY CHECK(id=1), payload TEXT NOT NULL, license TEXT NOT NULL)")
        database.execSQL("CREATE TABLE before_import (id INTEGER PRIMARY KEY CHECK(id=1), payload TEXT NOT NULL)")
        database.insertOrThrow("state", null, values(Backup(), License()))
    }
    override fun onUpgrade(database: SQLiteDatabase, oldVersion: Int, newVersion: Int) = error("Migration non disponible : $oldVersion vers $newVersion")
    fun load(): Pair<Backup, License> = readableDatabase.rawQuery("SELECT license FROM state WHERE id=1", null).use { cursor ->
        check(cursor.moveToFirst()) { "Données locales absentes ; aucune réinitialisation automatique n'a eu lieu." }
        read("state") to BackupCodec.json.decodeFromString<License>(cursor.getString(0))
    }
    fun previous(): Backup = read("before_import")
    private fun read(table: String): Backup {
        val length = readableDatabase.rawQuery("SELECT length(payload) FROM $table WHERE id=1", null).use { cursor -> require(cursor.moveToFirst()) { "Aucune sauvegarde disponible." }; cursor.getInt(0) }
        val text = buildString {
            var offset = 1
            while (offset <= length) {
                readableDatabase.rawQuery("SELECT substr(payload, ?, 131072) FROM $table WHERE id=1", arrayOf(offset.toString())).use { cursor -> check(cursor.moveToFirst()); append(cursor.getString(0)) }
                offset += 131072
            }
        }
        return BackupCodec.decode(text)
    }
    fun save(backup: Backup, license: License, importing: Boolean = false) {
        val values = values(backup, license)
        val database = writableDatabase
        database.beginTransaction()
        try {
            if (importing) database.execSQL("INSERT OR REPLACE INTO before_import (id,payload) SELECT id,payload FROM state WHERE id=1")
            check(database.update("state", values, "id=1", null) == 1)
            database.setTransactionSuccessful()
        } finally { database.endTransaction() }
    }
    private fun values(backup: Backup, license: License) = ContentValues().apply {
        val payload = BackupCodec.encode(backup)
        require(payload.toByteArray(Charsets.UTF_8).size <= 10_000_000) { "Limite de sauvegarde de 10 Mo atteinte." }
        put("id", 1); put("payload", payload); put("license", BackupCodec.json.encodeToString(license))
    }
}