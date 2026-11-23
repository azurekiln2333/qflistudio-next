package com.azurekiln.qflistudio

import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.util.Log
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

    /** Dart 已经取过一次批次，说明它可以收 `incoming`。 */
    private var dartListening: Boolean
        get() = listeningShared
        set(value) {
            listeningShared = value
        }

    /** 解析一个进来或新建的 intent。不是分享用的 intent 直接忽略。 */
    fun offer(intent: Intent?) {
        if (intent == null) return
        val uris = shareUris(intent)
        if (uris.isEmpty()) return
        val source = sourceOf(intent)
        val batchId = batchId()
        // 每个 intent 的 MIME 类型属于这个 intent，不能等到工作线程再问：
        // 那时 intent 可能已被下一个分享覆盖。
        val mimeType = intent.resolveType(context)
        worker.execute {
            val files = ArrayList<Map<String, Any?>>()
            var index = 0
            var batchBytes = 0L
            var tooLarge = false
            for (uri in uris) {
                if (files.size >= MAX_FILES) break
                // 一批总量上限：先看大小再复制，不把一个超限文件整份写盘。
                if (batchBytes >= MAX_BATCH_BYTES) {
                    tooLarge = true
                    break
                }
                val name = displayName(uri) ?: "shared_${index + 1}"
                val declaredSize = sizeOf(uri)
                if (declaredSize != null) {
                    if (declaredSize > MAX_FILE_BYTES) {
                        tooLarge = true
                        continue
                    }
                    if (batchBytes + declaredSize > MAX_BATCH_BYTES) {
                        tooLarge = true
                        break
                    }
                }
                val target = File(
                    File(File(context.filesDir, INBOX_DIR), batchId),
                    "%04d-%s".format(index + 1, safeName(name)),
                )
                try {
                    target.parentFile?.mkdirs()
                    val copied = copy(uri, target, MAX_BATCH_BYTES - batchBytes)
                    if (copied == null || copied < 0L) {
                        target.delete()
                        if (copied != null) tooLarge = true
                        continue
                    }
                    batchBytes += copied
                    files.add(
                        mapOf(
                            "path" to target.absolutePath,
                            "name" to name,
                            "bytes" to copied,
                            "mimeType" to mimeType,
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
                if (tooLarge) Log.w(TAG, "Every shared file was over the size limit ($source).")
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
                if (tooLarge) {
                    Log.w(TAG, "Shared files exceeded the size limits; some were skipped.")
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

    /**
     * Activity 重建时补投上一任桥缓存的批次。
     *
     * Dart 只会在启动时调一次 `takePending`；新桥若把批次只放进缓存，
     * 这一批就再也送不到界面，所以要主动推一次。
     */
    fun flushPending() {
        if (!dartListening) return
        val batch = pending ?: return
        pending = null
        channel.invokeMethod("incoming", batch)
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
        // 不中断在跑的复制：半截文件比晚到的批次更糟。
        worker.shutdown()
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

    private fun copy(uri: Uri, target: File, budget: Long): Long? {
        // 拿不到流就是读失败（null），不是空文件（0）。
        val input = context.contentResolver.openInputStream(uri) ?: return null
        input.use { source ->
            target.outputStream().use { sink ->
                val buffer = ByteArray(COPY_CHUNK)
                var total = 0L
                while (true) {
                    val read = source.read(buffer)
                    if (read <= 0) break
                    total += read
                    // 负数表示超限：调用方据此删除半成品。
                    if (total > MAX_FILE_BYTES) return -1L
                    if (total > budget) return -1L
                    sink.write(buffer, 0, read)
                }
                sink.flush()
                return total
            }
        }
    }

    /** 先用 OpenableColumns.SIZE 判断大小，拿不到返回 null。 */
    private fun sizeOf(uri: Uri): Long? {
        return try {
            context.contentResolver.query(
                uri,
                arrayOf(OpenableColumns.SIZE),
                null,
                null,
                null,
            )?.use { cursor: Cursor ->
                if (!cursor.moveToFirst()) return@use null
                val index = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (index < 0 || cursor.isNull(index)) null else cursor.getLong(index)
            }
        } catch (error: SecurityException) {
            null
        } catch (error: RuntimeException) {
            null
        }
    }

    companion object {
        const val CHANNEL = "qflistudio/share_inbox"
        private const val TAG = "ShareInbox"
        private const val INBOX_DIR = "shared_inbox"
        private const val MAX_FILES = 16
        private const val MAX_FILE_BYTES = 2L * 1024L * 1024L * 1024L
        private const val MAX_BATCH_BYTES = 512L * 1024L * 1024L
        private const val COPY_CHUNK = 1 shl 20

        // 进程级状态：Activity 重建会换一个新桥，而 Dart 侧早已听过通道。
        @Volatile
        private var listeningShared = false

        @Volatile
        private var pending: Map<String, Any?>? = null
    }

    private val BATCH_ID = Regex("[A-Za-z0-9_-]{1,64}")
}
