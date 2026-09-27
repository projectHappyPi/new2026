package com.happypi.parenting_log

import android.content.Context
import android.content.Intent
import com.happypi.parenting_log.widget.WidgetData
import com.happypi.parenting_log.widget.WidgetRender
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * "말로 기록" 바로가기(res/xml/shortcuts.xml)·딥링크 tunteuni://voice 로 앱이
 * 열렸는지 Dart 쪽(lib/features/voice/voice_launch.dart)에 알려준다.
 *
 * - 콜드 스타트: Dart가 준비된 뒤 consumeLaunch 로 한 번 가져간다(로딩 화면이
 *   몇 초 걸리므로 먼저 보내면 유실된다).
 * - 이미 켜져 있을 때: onNewIntent 에서 onLaunch 를 바로 보낸다.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pendingLaunch: Map<String, String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pendingLaunch = parseLaunch(intent)
        // 위젯 채널: 위젯 설정 저장 + 다시 그리기 (lib/features/widgets/widget_bridge.dart)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveConfig" -> {
                    val json = call.argument<String>("json")
                    getSharedPreferences(WidgetData.PREFS, Context.MODE_PRIVATE)
                        .edit().putString(WidgetData.KEY_CONFIG, json).apply()
                    WidgetRender.updateAll(applicationContext)
                    result.success(null)
                }
                "reload" -> {
                    WidgetRender.updateAll(applicationContext)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumeLaunch" -> {
                        result.success(pendingLaunch)
                        pendingLaunch = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val launch = parseLaunch(intent) ?: return
        val ch = channel
        if (ch == null) {
            pendingLaunch = launch
            return
        }
        // Dart 쪽 핸들러가 아직 없으면(로딩·온보딩 중) 보관했다가 consumeLaunch 로 넘긴다.
        ch.invokeMethod("onLaunch", launch, object : MethodChannel.Result {
            override fun success(result: Any?) {}
            override fun error(code: String, message: String?, details: Any?) {
                pendingLaunch = launch
            }
            override fun notImplemented() {
                pendingLaunch = launch
            }
        })
    }

    private fun parseLaunch(intent: Intent?): Map<String, String>? {
        if (intent == null) return null
        // 최근 앱 목록에서 복원될 때 예전 인텐트가 다시 오면 무시한다.
        if ((intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0) return null
        val data = intent.data ?: return null
        if (data.scheme != "tunteuni" || data.host != "voice") return null
        return mapOf("action" to "listen")
    }

    companion object {
        private const val CHANNEL = "com.happypi.parentingLog/voice_launch"
        private const val WIDGET_CHANNEL = "com.happypi.parentingLog/widget"
    }
}
