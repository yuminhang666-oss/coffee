package cn.coffeejournal.coffee_journal

import android.content.ContentResolver
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import android.os.Build
import android.util.AtomicFile
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.InputStream
import java.util.UUID
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream

/** Immutable media + atomic JSON pointer. Old media stays available to undo snapshots. */
class CoffeeFiles(private val root: File, private val cache: File, private val resolver: ContentResolver) {
    val media = File(root, "photos").apply { mkdirs() }
    private val current = AtomicFile(File(root, "coffee-v1.json"))
    private val previous = AtomicFile(File(root, "coffee-before-restore.json"))
    private val maxJson = 5_000_000
    private val maxBackup = 64_000_000
    private val photoName = Regex("^[a-f0-9-]{36}\\.jpg$")
    private fun exists(file: AtomicFile) = file.baseFile.exists() || File(file.baseFile.path + ".bak").exists()
    private fun read(file: AtomicFile): String? = if (exists(file)) file.openRead().use { bounded(it, maxJson).toString(Charsets.UTF_8) } else null
    fun read() = read(current)
    fun previous() = read(previous)
    private fun atomic(file: AtomicFile, bytes: ByteArray) {
        val output = file.startWrite()
        try { output.write(bytes); file.finishWrite(output) }
        catch (e: Exception) { file.failWrite(output); throw e }
    }
    private fun bounded(input: InputStream, limit: Int): ByteArray {
        val output = ByteArrayOutputStream()
        val buffer = ByteArray(8192)
        while (true) {
            val n = input.read(buffer)
            if (n < 0) break
            require(output.size().toLong() + n <= limit) { "文件超过大小限制" }
            output.write(buffer, 0, n)
        }
        return output.toByteArray()
    }
    fun preserveMigration() {
        val original = read() ?: return
        val migration = AtomicFile(File(root, "coffee-schema1-original.json"))
        if (!exists(migration)) atomic(migration, original.toByteArray(Charsets.UTF_8))
    }
    fun write(json: String, preserve: Boolean) {
        val bytes = json.toByteArray(Charsets.UTF_8)
        require(bytes.size <= maxJson)
        validatePhotos(json)
        if (preserve) {
            val old = read() ?: "{\"app\":\"coffee-journal\",\"schema\":2,\"beans\":[],\"cups\":[],\"adjustments\":[],\"theme\":\"system\",\"demo\":false,\"onboarded\":false}"
            atomic(previous, old.toByteArray(Charsets.UTF_8))
        }
        atomic(current, bytes)
    }
    private fun refs(json: String): Set<String> {
        val data = JSONObject(json)
        require(data.getString("app") == "coffee-journal" && data.getInt("schema") in 1..2) { "不支持的备份版本" }
        val beans = data.getJSONArray("beans")
        require(beans.length() <= 2000)
        val photos = mutableSetOf<String>()
        for (i in 0 until beans.length()) {
            val photo = beans.getJSONObject(i).optString("photo", "")
            require(photo.isEmpty() || photoName.matches(photo)) { "非法照片引用" }
            if (photo.isNotEmpty()) photos.add(photo)
        }
        return photos
    }
    private fun imageFiles(json: String): Set<String> = refs(json).flatMap { listOf(it, "thumb-$it") }.toSet()
    fun validatePhotos(json: String) {
        for (name in imageFiles(json)) require(File(media, name).isFile) { "照片缺失，请选择包含照片的完整备份" }
    }
    private fun jpeg(bitmap: Bitmap, quality: Int): ByteArray {
        val bytes = ByteArrayOutputStream()
        var q = quality
        do {
            bytes.reset()
            require(bitmap.compress(Bitmap.CompressFormat.JPEG, q, bytes))
            q -= 10
        } while (bytes.size() > 2_000_000 && q >= 34)
        require(bytes.size() <= 2_000_000) { "压缩后的照片超过 2 MB" }
        return bytes.toByteArray()
    }
    private fun resize(bitmap: Bitmap, side: Int): Bitmap {
        val scale = minOf(1.0, side.toDouble() / maxOf(bitmap.width, bitmap.height))
        return if (scale == 1.0) bitmap else Bitmap.createScaledBitmap(bitmap,
            maxOf(1, (bitmap.width * scale).toInt()), maxOf(1, (bitmap.height * scale).toInt()), true)
    }
    fun photo(uri: Uri): String {
        val temp = File.createTempFile("photo-", ".source", cache)
        try {
            resolver.openInputStream(uri)!!.use { temp.writeBytes(bounded(it, 30_000_000)) }
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(temp.path, bounds)
            require(bounds.outWidth > 0 && bounds.outHeight > 0 && bounds.outWidth.toLong() * bounds.outHeight <= 80_000_000) { "图片尺寸无效或超过 8000 万像素" }
            var bitmap: Bitmap = if (Build.VERSION.SDK_INT >= 28) {
                ImageDecoder.decodeBitmap(ImageDecoder.createSource(temp)) { decoder, info, _ ->
                    val factor = minOf(1.0, 1600.0 / maxOf(info.size.width, info.size.height))
                    decoder.setTargetSize(maxOf(1, (info.size.width * factor).toInt()), maxOf(1, (info.size.height * factor).toInt()))
                    decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                }
            } else {
                val options = BitmapFactory.Options().apply { inSampleSize = 1 }
                while (maxOf(bounds.outWidth, bounds.outHeight) / options.inSampleSize > 3200) options.inSampleSize *= 2
                val decoded = BitmapFactory.decodeFile(temp.path, options) ?: error("图片无法解码")
                val orientation = ExifInterface(temp.path).getAttributeInt(ExifInterface.TAG_ORIENTATION, 1)
                val matrix = Matrix()
                when (orientation) {
                    2 -> matrix.setScale(-1f, 1f)
                    3 -> matrix.setRotate(180f)
                    4 -> matrix.setScale(1f, -1f)
                    5 -> { matrix.setRotate(90f); matrix.postScale(-1f, 1f) }
                    6 -> matrix.setRotate(90f)
                    7 -> { matrix.setRotate(-90f); matrix.postScale(-1f, 1f) }
                    8 -> matrix.setRotate(-90f)
                }
                val oriented = Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)
                if (oriented !== decoded) decoded.recycle()
                oriented
            }
            val scaled = resize(bitmap, 1600)
            if (scaled !== bitmap) { bitmap.recycle(); bitmap = scaled }
            val name = UUID.randomUUID().toString() + ".jpg"
            atomic(AtomicFile(File(media, name)), jpeg(bitmap, 84))
            val thumb = resize(bitmap, 360)
            atomic(AtomicFile(File(media, "thumb-$name")), jpeg(thumb, 78))
            if (thumb !== bitmap) thumb.recycle()
            bitmap.recycle()
            return name
        } finally { temp.delete() }
    }
    fun export(uri: Uri, json: String) {
        validatePhotos(json)
        val names = imageFiles(json)
        require(names.sumOf { File(media, it).length() } + json.toByteArray().size < maxBackup - 1_000_000) { "完整备份超过 64 MB" }
        val manifest = JSONObject().put("app", "coffee-journal-backup").put("version", 2).put("photos", refs(json).size)
        resolver.openOutputStream(uri, "wt")!!.use { output -> ZipOutputStream(output).use { zip ->
            fun entry(name: String, bytes: ByteArray) { zip.putNextEntry(ZipEntry(name)); zip.write(bytes); zip.closeEntry() }
            entry("backup.json", manifest.toString().toByteArray(Charsets.UTF_8))
            entry("data.json", json.toByteArray(Charsets.UTF_8))
            for (name in names.sorted()) entry("photos/$name", File(media, name).readBytes())
        } }
    }
    private fun checkJpeg(file: File, side: Int) {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.path, options)
        require(options.outMimeType == "image/jpeg" && options.outWidth in 1..side && options.outHeight in 1..side) { "备份图片无效" }
        val bitmap = BitmapFactory.decodeFile(file.path, BitmapFactory.Options().apply { inSampleSize = 8 }) ?: error("图片损坏")
        bitmap.recycle()
    }
    fun import(uri: Uri): String {
        val source = File.createTempFile("import-", ".backup", cache)
        val stage = File(cache, "restore-${UUID.randomUUID()}").apply { mkdirs() }
        try {
            resolver.openInputStream(uri)!!.use { source.writeBytes(bounded(it, maxBackup)) }
            val zipHeader = source.inputStream().use { it.read() == 0x50 && it.read() == 0x4b }
            if (!zipHeader) {
                require(source.length() <= maxJson) { "JSON 超过 5 MB" }
                val json = source.readText(Charsets.UTF_8)
                require(refs(json).isEmpty()) { "含照片的备份必须使用完整 ZIP" }
                return json
            }
            val seen = mutableSetOf<String>()
            var total = 0L
            ZipInputStream(source.inputStream()).use { zip ->
                while (true) {
                    val entry = zip.nextEntry ?: break
                    val name = entry.name
                    require(seen.size < 4002 && seen.add(name) && !entry.isDirectory) { "重复条目或文件过多" }
                    require(name == "backup.json" || name == "data.json" || Regex("^photos/(thumb-)?[a-f0-9-]{36}\\.jpg$").matches(name)) { "非法路径或未知条目" }
                    val bytes = bounded(zip, if (name == "data.json") maxJson else if (name == "backup.json") 4096 else 2_000_000)
                    total += bytes.size
                    require(total <= maxBackup) { "解压内容超过 64 MB" }
                    // Only validated flat names are used; never extract an archive path.
                    File(stage, name.substringAfterLast('/')).writeBytes(bytes)
                    zip.closeEntry()
                }
            }
            val manifest = JSONObject(File(stage, "backup.json").readText(Charsets.UTF_8))
            require(manifest.getString("app") == "coffee-journal-backup" && manifest.get("version") == 2) { "不支持的完整备份版本" }
            val json = File(stage, "data.json").readText(Charsets.UTF_8)
            require(JSONObject(json).get("schema") == 2) { "完整备份数据版本无效" }
            val names = imageFiles(json)
            require(manifest.get("photos") == refs(json).size && seen == names.map { "photos/$it" }.toSet() + setOf("backup.json", "data.json")) { "照片缺失、数量不符或非法引用" }
            for (name in names) {
                val file = File(stage, name)
                checkJpeg(file, if (name.startsWith("thumb-")) 360 else 1600)
                val existing = File(media, name)
                require(!existing.exists() || existing.readBytes().contentEquals(file.readBytes())) { "同名照片内容冲突，当前照片已保留" }
            }
            // Unreferenced immutable files cannot affect current or undo data.
            // Dart then validates all domain fields before offering confirmation.
            for (name in names) if (!File(media, name).exists()) atomic(AtomicFile(File(media, name)), File(stage, name).readBytes())
            return json
        } finally { source.delete(); stage.deleteRecursively() }
    }
}
