package com.azurekiln.qflistudio

import android.content.Intent
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
}
