package cn.coffeejournal.coffee_journal

import android.app.Activity
import android.app.Instrumentation
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.ExifInterface
import android.net.Uri
import android.os.Bundle
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.UUID
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream

/** Dependency-free native regression runner, present in debug builds only.
 * Uses synthetic fixtures in its own cache directory; never replaces the app's actual data.
 * adb shell am instrument -w cn.coffeejournal.coffee_journal/.CoffeeValidation
 */
class CoffeeValidation : Instrumentation() {
    override fun onCreate(arguments: Bundle?) { super.onCreate(arguments); start() }
    override fun onStart() {
        val results = JSONArray()
        val directory = File(targetContext.cacheDir, "native-qa-${UUID.randomUUID()}").apply { mkdirs() }
        fun test(name: String, run: () -> Unit) {
            run()
            results.put(JSONObject().put("test", name).put("passed", true))
        }
        try {
            val root = File(directory, "first").apply { mkdirs() }
            val cache = File(directory, "cache").apply { mkdirs() }
            val files = CoffeeFiles(root, cache, targetContext.contentResolver)
            val source = File(directory, "synthetic-bag.jpg")
            val bitmap = Bitmap.createBitmap(2400, 1200, Bitmap.Config.ARGB_8888)
            bitmap.eraseColor(0xffab784e.toInt())
            source.outputStream().use { check(bitmap.compress(Bitmap.CompressFormat.JPEG, 95, it)) }
            bitmap.recycle()
            val exif = ExifInterface(source.path)
            exif.setAttribute(ExifInterface.TAG_ORIENTATION, "6"); exif.saveAttributes()
            var photo = ""
            fun data(name: String = "Synthetic QA", photoRef: String = photo): String = JSONObject()
                .put("app", "coffee-journal").put("schema", 2).put("theme", "dark").put("demo", true).put("onboarded", true)
                .put("beans", JSONArray().put(JSONObject().put("id", "native-bag").put("name", name).put("photo", photoRef)
                    .put("weightTenths", 2500).put("cents", 8800).put("origin", "").put("roast", "浅烘").put("process", "").put("roaster", "QA").put("note", "")))
                .put("cups", JSONArray()).put("adjustments", JSONArray()).toString()
            test("Photo picker copy, EXIF orientation, bounded original and thumbnail") {
                photo = files.photo(Uri.fromFile(source))
                val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeFile(File(files.media, photo).path, bounds)
                check(bounds.outWidth == 800 && bounds.outHeight == 1600)
                BitmapFactory.decodeFile(File(files.media, "thumb-$photo").path, bounds)
                check(bounds.outWidth == 180 && bounds.outHeight == 360)
                source.delete(); check(File(files.media, photo).isFile)
            }
            test("Migration original retained byte for byte, never overwritten") {
                val legacy = data().replace("\"schema\":2", "\"schema\":1")
                File(root, "coffee-v1.json").writeText(legacy)
                files.preserveMigration(); files.write(data(), false); files.preserveMigration()
                check(File(root, "coffee-schema1-original.json").readText() == legacy)
            }
            val before = data()
            files.write(before, false)
            test("Photo removal/replacement never deletes other or undo references") {
                files.write(data("Removed", ""), true)
                check(File(files.media, photo).isFile)
                check(files.previous() == before)
                files.write(files.previous()!!, false)
                check(CoffeeFiles(root, cache, targetContext.contentResolver).read() == before)
            }
            val archive = File(directory, "complete.zip")
            test("Full backup and restore round trip into an independent store") {
                files.export(Uri.fromFile(archive), before)
                val secondRoot = File(directory, "second").apply { mkdirs() }
                val second = CoffeeFiles(secondRoot, cache, targetContext.contentResolver)
                val restored = second.import(Uri.fromFile(archive))
                second.write(restored, false)
                check(restored == before)
                check(File(second.media, photo).readBytes().contentEquals(File(files.media, photo).readBytes()))
                check(File(second.media, "thumb-$photo").readBytes().contentEquals(File(files.media, "thumb-$photo").readBytes()))
            }
            val entries = linkedMapOf<String, ByteArray>()
            ZipInputStream(archive.inputStream()).use { zip -> while(true) {
                val e = zip.nextEntry ?: break; entries[e.name] = zip.readBytes(); zip.closeEntry()
            } }
            fun zipFile(name: String, values: Map<String, ByteArray>): File {
                val f = File(directory, name)
                ZipOutputStream(f.outputStream()).use { zip -> for ((n,bytes) in values) {
                    zip.putNextEntry(ZipEntry(n)); zip.write(bytes); zip.closeEntry()
                } }
                return f
            }
            fun rejected(name: String, file: File) = test(name) {
                var failed = false
                try { val candidate = files.import(Uri.fromFile(file)); files.write(candidate, true) }
                catch (_: Exception) { failed = true }
                check(failed); check(files.read() == before)
                check(File(files.media, photo).readBytes().contentEquals(entries["photos/$photo"]))
                check(File(files.media, "thumb-$photo").isFile)
            }
            rejected("Path traversal rejected; current data and photos unchanged", zipFile("traversal.zip", entries + ("../escape.jpg" to byteArrayOf(1))))
            rejected("Unknown entry rejected", zipFile("unknown.zip", entries + ("unknown.txt" to byteArrayOf(1))))
            rejected("Missing photo rejected", zipFile("missing.zip", entries.filterKeys { it != "photos/$photo" }))
            rejected("Missing thumbnail rejected", zipFile("missing-thumb.zip", entries.filterKeys { it != "photos/thumb-$photo" }))
            rejected("Unsupported ZIP version rejected", zipFile("future.zip", entries + ("backup.json" to "{\"app\":\"coffee-journal-backup\",\"version\":99,\"photos\":1}".toByteArray())))
            rejected("Fractional ZIP version rejected", zipFile("fraction.zip", entries + ("backup.json" to "{\"app\":\"coffee-journal-backup\",\"version\":2.5,\"photos\":1}".toByteArray())))
            rejected("Noninteger photo count rejected", zipFile("fraction-count.zip", entries + ("backup.json" to "{\"app\":\"coffee-journal-backup\",\"version\":2,\"photos\":1.5}".toByteArray())))
            rejected("Corrupted JPEG rejected", zipFile("bad-photo.zip", entries + ("photos/$photo" to byteArrayOf(1,2,3))))
            rejected("Illegal reference rejected", zipFile("bad-ref.zip", entries + ("data.json" to before.replace(photo, "../escape.jpg").toByteArray())))
            rejected("Photo count mismatch rejected", zipFile("bad-count.zip", entries + ("backup.json" to "{\"app\":\"coffee-journal-backup\",\"version\":2,\"photos\":2}".toByteArray())))
            rejected("Oversized JSON entry rejected", zipFile("oversize.zip", entries + ("data.json" to ByteArray(5_000_001) { 32 })))
            val duplicate = zipFile("duplicate.zip", entries + ("evil.json" to entries["data.json"]!!))
            val duplicateBytes = duplicate.readBytes()
            val find = "evil.json".toByteArray(); val replace = "data.json".toByteArray()
            for (i in 0..duplicateBytes.size-find.size) if (find.indices.all { duplicateBytes[i+it] == find[it] }) replace.copyInto(duplicateBytes,i)
            duplicate.writeBytes(duplicateBytes)
            rejected("Duplicate ZIP entries rejected", duplicate)
            val excessive = linkedMapOf<String, ByteArray>()
            for (i in 0..4002) excessive["photos/${UUID.randomUUID()}.jpg"] = byteArrayOf()
            rejected("File count limit enforced", zipFile("too-many.zip", excessive))
            test("Legacy JSON accepted without current replacement") {
                val old = File(directory, "old.json").apply { writeText(data(photoRef="").replace("\"schema\":2", "\"schema\":1")) }
                check(files.import(Uri.fromFile(old)) == old.readText()); check(files.read() == before)
            }
            val future = File(directory, "future.json").apply { writeText(data(photoRef="").replace("\"schema\":2", "\"schema\":99")) }
            rejected("Unknown JSON schema rejected", future)
            test("Missing media prevents commit without changing current snapshot") {
                var failed = false
                try { files.write(data(photoRef="11111111-1111-1111-1111-111111111111.jpg"), true) } catch (_: Exception) { failed = true }
                check(failed); check(files.read() == before)
            }
            test("Schema 3 complete ZIP preserves decimal water, structured bean, custom vocabulary and sensory") {
                val upgraded = JSONObject(before).put("schema", 3)
                upgraded.put("customFlavors", JSONArray().put(JSONObject().put("id", "custom-qa").put("label", "Synthetic aroma").put("group", "floral").put("active", false)))
                upgraded.getJSONArray("beans").getJSONObject(0).put("roast", "ultraLight")
                    .put("origin", "Unparsed original").put("country", "Unknown").put("region", "QA region")
                    .put("farm", "QA farm").put("station", "QA station").put("varieties", JSONArray().put("QA variety"))
                    .put("bagFlavors", JSONArray().put("Jasmine"))
                    .put("sensory", JSONArray().put(JSONObject.NULL).put(0).put(1).put(5).put(10).put(JSONObject.NULL))
                upgraded.put("cups", JSONArray().put(JSONObject().put("id", "native-cup").put("beanId", "native-bag")
                    .put("gramsTenths", 155).put("waterTenths", 2405).put("seconds", 150).put("temperature", JSONObject.NULL)
                    .put("tastes", JSONArray().put("Historical aroma")).put("tasteIds", JSONArray().put("custom-qa"))))
                val json = upgraded.toString()
                files.write(json, false)
                val zip = File(directory, "schema3.zip")
                files.export(Uri.fromFile(zip), json)
                val third = CoffeeFiles(File(directory,"third").apply { mkdirs() }, cache, targetContext.contentResolver)
                val imported = third.import(Uri.fromFile(zip))
                check(imported == json)
                third.write(imported, false)
                check(CoffeeFiles(File(directory,"third"),cache,targetContext.contentResolver).read() == json)
                files.write(before, true)
                check(files.previous() == json)
                files.write(files.previous()!!, false)
                check(files.read() == json)
                check(File(files.media,photo).isFile)
                files.write(before, false)
            }
            test("Schema 2 migration source retained independently; failed preservation does not overwrite") {
                files.write(before, false)
                files.preserveMigration()
                check(File(root,"coffee-schema2-original.json").readText() == before)
                val blockedRoot = File(directory,"blocked").apply { mkdirs() }
                val blocked = CoffeeFiles(blockedRoot,cache,targetContext.contentResolver)
                File(blockedRoot,"coffee-v1.json").writeText(before)
                File(blockedRoot,"coffee-schema2-original.json").mkdirs()
                var failed = false
                try { blocked.preserveMigration() } catch (_: Exception) { failed=true }
                check(failed)
                check(blocked.read() == before)
            }
            val output = Bundle().apply { putString("results", results.toString()); putInt("passed",results.length()) }
            finish(Activity.RESULT_OK, output)
        } catch (e: Throwable) {
            finish(Activity.RESULT_CANCELED, Bundle().apply { putString("results",results.toString()); putString("failure", e.stackTraceToString()) })
        } finally { directory.deleteRecursively() }
    }
}
