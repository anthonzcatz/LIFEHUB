package com.lifehub.app

import android.content.Intent
import android.os.Build
import android.provider.Settings
import androidx.annotation.NonNull
import androidx.biometric.BiometricManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "lifehub/security"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canAuthenticateBiometric" -> {
                        try {
                            val manager = BiometricManager.from(this)
                            val status = manager.canAuthenticate(
                                BiometricManager.Authenticators.BIOMETRIC_STRONG
                            )
                            result.success(status == BiometricManager.BIOMETRIC_SUCCESS)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                    "openBiometricEnrollment" -> {
                        try {
                            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                                Intent(Settings.ACTION_BIOMETRIC_ENROLL)
                            } else {
                                Intent(Settings.ACTION_SECURITY_SETTINGS)
                            }
                            startActivity(intent)
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
