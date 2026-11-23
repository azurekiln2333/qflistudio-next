package com.azurekiln.qflistudio

import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.UUID
import java.util.concurrent.Executors

/**
 * 接收别的应用分享的文件。
 *
 * 文件先复制进 `filesDir/shared_inbox/<批次>/`，再把批次交给 Dart。
 * 复制放在工作线程：微信给的 content URI 授权会过期，等 Dart 起来再读就晚了。
 *
 * 一轮只保留最后一批：Dart 还没注册通道时先缓存，由 `takePending` 取走。
 */
class ShareInboxBridge(
    private val context: Context,
    private val channel: MethodChannel,
) {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()

    private var pending: Map<String, Any?>? = null

    /** Dart 已经取过一次批次，说明它可以收 `incoming`。 */
    private var dartListening = false

    /** 解析一个进来或新建的 intent。不是分享用的 intent 直接忽略。 */
    fun offer(intent: Intent?) {
        if (intent == null) return
        val uris = shareUris(intent)
        if (uris.isEmpty()) return
        val source = sourceOf(intent)
        val batchId = batchId()
        worker.execute {
            val files = ArrayList<Map<String, Any?>>()
            var index = 0
            var totalBytes = 0L
            for (uri in uris) {
                if (files.size >= MAX_FILES) break
                if (totalBytes >= MAX_BATCH_BYTES) break
                val name = displayName(uri) ?: "shared_${index + 1}"
                val target = File(
                    File(File(context.filesDir, INBOX_DIR), batchId),
                    "%04d-%s".format(index + 1, safeName(name)),
                )
                try {
                    target.parentFile?.mkdirs()
                    val copied = copy(uri, target)
                    if (copied <= 0L) {
                        target.delete()
                        continue
                    }
                    totalBytes += copied
                    files.add(
                        mapOf(
                            "path" to target.absolutePath,
                            "name" to name,
                            "bytes" to copied,
                            "mimeType" to intent.resolveType(context),
                        ),
                    )
                    index++
                } catch (error: IOException) {
                    target.delete()
                } catch (error: SecurityException) {
                    target.delete()
                }
            }
            if (files.isEmpty()) {
                File(File(context.filesDir, INBOX_DIR), batchId).deleteRecursively()
                return@execute
            }
            val batch = mapOf<String, Any?>(
                "id" to batchId,
                "coldStart" to !dartListening,
                "source" to source,
                "files" to files,
            )
            mainHandler.post {
                if (dartListening) {
                    channel.invokeMethod("incoming", batch)
                } else {
                    pending = batch
                }
            }
        }
    }

    /** Dart 起来后取走冷启动批次。 */
    fun takePending(result: MethodChannel.Result) {
        dartListening = true
        val batch = pending
        pending = null
        result.success(batch)
    }

    /** 删除一个批次目录。目录名校验与 Dart 侧一致。 */
    fun discard(id: String?, result: MethodChannel.Result) {
        if (id == null || !BATCH_ID.matches(id)) {
            result.error("INVALID_ARGUMENT", "批次 id 无效", null)
            return
        }
        File(File(context.filesDir, INBOX_DIR), id).deleteRecursively()
        result.success(null)
    }

    fun dispose() {
        worker.shutdownNow()
    }

    private fun shareUris(intent: Intent): List<Uri> {
        val uris = ArrayList<Uri>()
        when (intent.action) {
            Intent.ACTION_SEND -> streamUri(intent)?.let { uris.add(it) }
            Intent.ACTION_SEND_MULTIPLE -> {
                @Suppress("DEPRECATION")
                val list = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                list?.forEach { uris.add(it) }
            }
            Intent.ACTION_VIEW -> intent.data?.let { uris.add(it) }
            else -> return emptyList()
        }
        return uris.filter { it.scheme == "content" || it.scheme == "file" }
    }

    @Suppress("DEPRECATION")
    private fun streamUri(intent: Intent): Uri? {
        intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)?.let { return it }
        val clip = intent.clipData ?: return null
        if (clip.itemCount == 0) return null
        return clip.getItemAt(0).uri
    }

    private fun sourceOf(intent: Intent): String = when (intent.action) {
        Intent.ACTION_SEND -> "send"
        Intent.ACTION_SEND_MULTIPLE -> "sendMultiple"
        Intent.ACTION_VIEW -> "view"
        else -> "send"
    }

    private fun batchId(): String =
        "${System.currentTimeMillis()}-${UUID.randomUUID().toString().take(4)}"

    private fun displayName(uri: Uri): String? {
        return try {
            context.contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { cursor: Cursor ->
                if (!cursor.moveToFirst()) return@use null
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index < 0 || cursor.isNull(index)) null else cursor.getString(index)
            }
        } catch (error: SecurityException) {
            null
        } catch (error: RuntimeException) {
            null
        }
    }

    private fun safeName(name: String): String {
        val flattened = name.takeIf { it.isNotBlank() } ?: "shared-file"
        return flattened
            .replace(Regex("[\\\\/:*?\"<>|\\u0000-\\u001f]"), "_")
            .take(120)
    }

    private fun copy(uri: Uri, target: File): Long {
        val input = context.contentResolver.openInputStream(uri) ?: return -1L
        input.use { source ->
            target.outputStream().use { sink ->
                val buffer = ByteArray(1 shl 20)
                var total = 0L
                while (true) {
                    val read = source.read(buffer)
                    if (read <= 0) break
                    total += read
                    if (total > MAX_FILE_BYTES) return -1L
                    sink.write(buffer, 0, read)
                }
                sink.flush()
                return total
            }
        }
    }

    companion object {
        const val CHANNEL = "qflistudio/share_inbox"
        private const val INBOX_DIR = "shared_inbox"
        private const val MAX_FILES = 16
        private const val MAX_FILE_BYTES = 2L * 1024L * 1024L * 1024L
        private const val MAX_BATCH_BYTES = 512L * 1024L * 1024L
    }

    private val BATCH_ID = Regex("[A-Za-z0-9_-]{1,64}")
}
