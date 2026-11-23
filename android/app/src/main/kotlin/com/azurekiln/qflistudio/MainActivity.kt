package com.azurekiln.qflistudio

import android.content.Intent
import android.hardware.display.DisplayManager
import android.os.Build
import android.util.DisplayMetrics
import android.view.Display
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var shareInbox: ShareInboxBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ShareInboxBridge.CHANNEL,
        )
        val bridge = ShareInboxBridge(applicationContext, channel)
        shareInbox = bridge
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "takePending" -> bridge.takePending(result)
                "discard" -> bridge.discard(call.argument<String>("id"), result)
                else -> result.notImplemented()
            }
        }
        // 冷启动：进程由分享 intent 拉起。
        bridge.offer(intent)
        // Activity 重建：上一任桥可能留下了没送出去的批次。
        bridge.flushPending()

        registerFormFactorChannel(flutterEngine)
    }

    /**
     * 设备类别：只读硬件形态，不看当前窗口宽度，也不看是否接了鼠标。
     *
     * 分屏会把 Activity 的 configuration 宽度压到手机级别，所以这里读
     * 最大窗口边界换算逻辑短边。这是分类近似，折叠设备与外接显示器
     * 以真机验收为准。
     */
    private fun registerFormFactorChannel(flutterEngine: FlutterEngine) {
        val formFactor = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            FORM_FACTOR_CHANNEL,
        )
        formFactor.setMethodCallHandler { call, result ->
            if (call.method != "getFormFactor") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val shortestDp = shortestDisplaySideDp()
            if (shortestDp == null) {
                result.error("UNAVAILABLE", "Display metrics are unavailable.", null)
                return@setMethodCallHandler
            }
            result.success(if (shortestDp >= TABLET_MIN_SHORTEST_DP) "tablet" else "phone")
        }
    }

    /**
     * 设备类别的分类近似值：完整显示区域的逻辑短边。
     *
     * maximumWindowMetrics 给出该显示器能提供的最大窗口边界，不是始终等于
     * 物理面板尺寸，但能把常驻状态栏与分屏的临时压窄排除在外。
     * 这是分类近似，不是硬件事实：折叠设备与外接显示器以真机验收为准。
     */
    @Suppress("DEPRECATION")
    private fun shortestDisplaySideDp(): Float? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val manager = getSystemService(WINDOW_SERVICE) as android.view.WindowManager
            val bounds = manager.maximumWindowMetrics.bounds
            val density = resources.displayMetrics.density
            if (density <= 0f || bounds.width() <= 0 || bounds.height() <= 0) return null
            return minOf(bounds.width(), bounds.height()) / density
        }
        // R 之前退回 getRealMetrics：同样读整块显示区域，不读当前窗口。
        val display = defaultDisplay() ?: return null
        val metrics = DisplayMetrics()
        display.getRealMetrics(metrics)
        if (metrics.densityDpi <= 0) return null
        val density = metrics.densityDpi / 160f
        return minOf(metrics.widthPixels, metrics.heightPixels) / density
    }

    private fun defaultDisplay(): Display? {
        return try {
            val manager = getSystemService(DISPLAY_SERVICE) as DisplayManager
            manager.getDisplay(Display.DEFAULT_DISPLAY)
        } catch (_: Exception) {
            null
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // 热启动：Activity 已在，新 intent 走这里。
        shareInbox?.offer(intent)
    }

    override fun onDestroy() {
        shareInbox?.dispose()
        shareInbox = null
        super.onDestroy()
    }

    private companion object {
        const val FORM_FACTOR_CHANNEL = "qflistudio/form_factor"

        /** 与 Dart 侧的回退阈值一致：600 逻辑像素。 */
        const val TABLET_MIN_SHORTEST_DP = 600f
    }
}
