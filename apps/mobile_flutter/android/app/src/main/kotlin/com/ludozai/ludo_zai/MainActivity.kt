package com.ludozai.ludo_zai

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "com.ludozai.ludo_zai/keep_alive"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startKeepAlive" -> {
                        val title = call.argument<String>("title") ?: "Ludo-Z! Game Active"
                        val body = call.argument<String>("body")
                            ?: "Match background mein chal raha hai — wapas aane ke liye tap karein."
                        val svcIntent = Intent(this, LudoKeepAliveService::class.java).apply {
                            putExtra(LudoKeepAliveService.EXTRA_TITLE, title)
                            putExtra(LudoKeepAliveService.EXTRA_BODY, body)
                        }
                        try {
                            ContextCompat.startForegroundService(this, svcIntent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }

                    "stopKeepAlive" -> {
                        try {
                            stopService(Intent(this, LudoKeepAliveService::class.java))
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }

                    "moveToBackground" -> {
                        // Minimizes app without killing the match or Flutter engine
                        moveTaskToBack(true)
                        result.success(true)
                    }

                    "requestIgnoreBatteryOptimizations" -> {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                                if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                        data = Uri.parse("package:$packageName")
                                    }
                                    startActivity(intent)
                                }
                            }
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
