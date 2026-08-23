package com.example.rescue35

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "rescue35/native_actions"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "dial" -> {
                    val number = call.argument<String>("number").orEmpty()
                    val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$number"))
                    startActivity(intent)
                    result.success(null)
                }
                "map" -> {
                    val address = call.argument<String>("address").orEmpty()
                    val encodedAddress = Uri.encode(address)
                    val intent = Intent(
                        Intent.ACTION_VIEW,
                        Uri.parse("geo:0,0?q=$encodedAddress")
                    )
                    startActivity(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
