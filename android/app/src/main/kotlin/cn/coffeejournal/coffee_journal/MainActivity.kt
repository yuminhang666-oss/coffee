package cn.coffeejournal.coffee_journal

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val io = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null
    private var exportText: String? = null
    private lateinit var files: CoffeeFiles
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        files = CoffeeFiles(filesDir, cacheDir, contentResolver)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "coffee_journal/storage").setMethodCallHandler { call, result ->
            if (call.method in listOf("export", "import", "photo")) {
                if (pending != null) { result.error("BUSY", "文件选择器正在使用", null); return@setMethodCallHandler }
                pending = result
                val export = call.method == "export"
                exportText = if (export) call.arguments as String else null
                try {
                    val intent = Intent(if (export) Intent.ACTION_CREATE_DOCUMENT else Intent.ACTION_OPEN_DOCUMENT)
                    intent.addCategory(Intent.CATEGORY_OPENABLE)
                    intent.type = if (export) "application/zip" else if (call.method == "photo") "image/*" else "*/*"
                    if (export) intent.putExtra(Intent.EXTRA_TITLE, "coffee-journal-v2-${System.currentTimeMillis()}.zip")
                    @Suppress("DEPRECATION")
                    startActivityForResult(intent, if (export) 701 else if (call.method == "photo") 703 else 702)
                } catch (_: Exception) { pending = null; exportText = null; result.error("PICKER", "无法打开系统文件选择器", null) }
            } else io.execute {
                try {
                    val response: Any? = when (call.method) {
                        "read" -> files.read()
                        "write" -> { files.write(call.argument<String>("json")!!, call.argument<Boolean>("preserve") == true); null }
                        "previous" -> files.previous()
                        "mediaRoot" -> files.media.absolutePath
                        "preserveMigration" -> { files.preserveMigration(); null }
                        "validatePhotos" -> { files.validatePhotos(call.arguments as String); null }
                        else -> throw IllegalArgumentException("Unknown operation")
                    }
                    runOnUiThread { result.success(response) }
                } catch (e: Exception) { runOnUiThread { result.error("STORAGE", e.message ?: "本机记录读写失败", null) } }
            }
        }
    }
    @Deprecated("Flutter activity result bridge")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode !in 701..703) { super.onActivityResult(requestCode, resultCode, data); return }
        val result = pending ?: return
        val text = exportText
        pending = null; exportText = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { result.success(if (requestCode == 701) false else null); return }
        io.execute {
            try {
                val response: Any? = when (requestCode) {
                    701 -> { files.export(uri, text!!); true }
                    703 -> files.photo(uri)
                    else -> files.import(uri)
                }
                runOnUiThread { result.success(response) }
            } catch (e: Exception) { runOnUiThread { result.error("FILE", e.message ?: "文件无效或超过限制", null) } }
        }
    }
}
