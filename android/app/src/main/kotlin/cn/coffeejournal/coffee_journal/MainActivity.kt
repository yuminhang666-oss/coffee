package cn.coffeejournal.coffee_journal

import android.app.Activity
import android.content.Intent
import android.util.AtomicFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.InputStream
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val io = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null
    private var exportText: String? = null
    private val limit = 5_000_000
    private fun bounded(input: InputStream): ByteArray {
        val output = ByteArrayOutputStream()
        val buffer = ByteArray(8192)
        while (true) {
            val n = input.read(buffer)
            if (n < 0) break
            require(output.size() + n <= limit)
            output.write(buffer, 0, n)
        }
        return output.toByteArray()
    }
    private fun atomic(file: AtomicFile, bytes: ByteArray) {
        val out = file.startWrite()
        try { out.write(bytes); file.finishWrite(out) }
        catch (e: Exception) { file.failWrite(out); throw e }
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val file = AtomicFile(File(filesDir, "coffee-v1.json"))
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "coffee_journal/storage").setMethodCallHandler { call, result ->
            when (call.method) {
                "read", "write" -> io.execute {
                    try {
                        var response: String? = null
                        if (call.method == "read") {
                            if (file.baseFile.exists() || File(file.baseFile.path + ".bak").exists()) {
                                response = file.openRead().use { input ->
                                    val bytes = bounded(input)
                                    bytes.toString(Charsets.UTF_8)
                                }
                            }
                        } else {
                            val text = call.argument<String>("json") ?: error("Missing JSON")
                            val bytes = text.toByteArray(Charsets.UTF_8)
                            require(bytes.size <= limit)
                            if (call.argument<Boolean>("preserve") == true && file.baseFile.exists()) {
                                atomic(AtomicFile(File(filesDir, "coffee-before-restore.json")), file.openRead().use { it.readBytes() })
                            }
                            atomic(file, bytes)
                        }
                        runOnUiThread { result.success(response) }
                    } catch (_: Exception) { runOnUiThread { result.error("STORAGE", "本机记录读写失败", null) } }
                }
                "export", "import" -> {
                    if (pending != null) { result.error("BUSY", "文件选择器正在使用", null) }
                    else {
                        pending = result
                        try {
                            val export = call.method == "export"
                            exportText = if (export) call.arguments as String else null
                            val intent = Intent(if (export) Intent.ACTION_CREATE_DOCUMENT else Intent.ACTION_OPEN_DOCUMENT)
                            intent.addCategory(Intent.CATEGORY_OPENABLE)
                            intent.type = if (export) "application/json" else "*/*"
                            if (export) intent.putExtra(Intent.EXTRA_TITLE, "coffee-journal-${System.currentTimeMillis()}.json")
                            @Suppress("DEPRECATION")
                            startActivityForResult(intent, if (export) 701 else 702)
                        } catch (_: Exception) { pending = null; exportText = null; result.error("PICKER", "无法打开系统文件选择器", null) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    @Deprecated("Legacy result API required by FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != 701 && requestCode != 702) { super.onActivityResult(requestCode, resultCode, data); return }
        val result = pending ?: return
        val text = exportText
        pending = null; exportText = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { result.success(if (requestCode == 701) false else null); return }
        io.execute {
            try {
                if (requestCode == 701) {
                    contentResolver.openOutputStream(uri, "wt")!!.use { it.write(text!!.toByteArray(Charsets.UTF_8)); it.flush() }
                    runOnUiThread { result.success(true) }
                } else {
                    val bytes = contentResolver.openInputStream(uri)!!.use { bounded(it) }
                    runOnUiThread { result.success(bytes.toString(Charsets.UTF_8)) }
                }
            } catch (_: Exception) { runOnUiThread { result.error("FILE", "文件读写失败或文件超过 5 MB", null) } }
        }
    }
}
