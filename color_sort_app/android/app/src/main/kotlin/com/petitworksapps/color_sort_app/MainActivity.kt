package com.petitworksapps.color_sort_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 町の絵(PNG)を受け取り、ホーム画面ウィジェットを更新する。
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "everpuzz/home_widget")
            .setMethodCallHandler { call, result ->
                if (call.method == "update") {
                    val png = call.argument<ByteArray>("png")
                    if (png == null) {
                        result.error("bad_args", "png is required", null)
                    } else {
                        TownWidgetProvider.save(applicationContext, png)
                        result.success(null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
