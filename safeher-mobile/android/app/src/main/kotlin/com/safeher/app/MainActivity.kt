package com.safeher.app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val BATTERY_CHANNEL = "com.safeher.app/battery"
    private val VIBRATE_CHANNEL = "com.safeher.app/vibrate"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Native Vibration Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VIBRATE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "vibratePattern", "vibrateEmergency" -> {
                    try {
                        val pattern = if (call.method == "vibrateEmergency") {
                            longArrayOf(0, 500, 200, 500, 200, 500)
                        } else {
                            longArrayOf(0, 400, 150, 400)
                        }

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                            val vibrator = vibratorManager.defaultVibrator
                            vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
                        } else {
                            @Suppress("DEPRECATION")
                            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
                            } else {
                                vibrator.vibrate(pattern, -1)
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Native Battery Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isBatteryOptimizationDisabled" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                        val isIgnoring = powerManager.isIgnoringBatteryOptimizations(packageName)
                        result.success(isIgnoring)
                    } else {
                        result.success(true)
                    }
                }
                "requestDisableBatteryOptimization" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            try {
                                val fallbackIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                                startActivity(fallbackIntent)
                                result.success(true)
                            } catch (e2: Exception) {
                                result.success(false)
                            }
                        }
                    } else {
                        result.success(true)
                    }
                }
                "openAutoStartSettings" -> {
                    val manufacturer = Build.MANUFACTURER.lowercase()
                    val intents = mutableListOf<Intent>()

                    when {
                        manufacturer.contains("xiaomi") || manufacturer.contains("redmi") || manufacturer.contains("poco") -> {
                            intents.add(Intent().setClassName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"))
                        }
                        manufacturer.contains("oppo") || manufacturer.contains("realme") -> {
                            intents.add(Intent().setClassName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"))
                            intents.add(Intent().setClassName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity"))
                        }
                        manufacturer.contains("vivo") || manufacturer.contains("iqoo") -> {
                            intents.add(Intent().setClassName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"))
                            intents.add(Intent().setClassName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"))
                        }
                        manufacturer.contains("oneplus") -> {
                            intents.add(Intent().setClassName("com.oneplus.security", "com.oneplus.security.chainlaunch.view.ChainLaunchAppListAct"))
                        }
                    }

                    var started = false
                    for (intent in intents) {
                        try {
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            started = true
                            break
                        } catch (e: Exception) {
                            // try next intent
                        }
                    }

                    if (!started) {
                        try {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                        } catch (e: Exception) {
                            // Ignore
                        }
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
