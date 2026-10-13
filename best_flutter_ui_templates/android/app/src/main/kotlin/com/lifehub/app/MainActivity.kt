package com.lifehub.app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.provider.Settings
import androidx.annotation.NonNull
import androidx.biometric.BiometricManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "lifehub/security"

    private var pendingPick: MethodChannel.Result? = null
    private var capturePhotoPath: String? = null

    companion object {
        private const val RC_PICK_FILE = 0x7A01
        private const val RC_PICK_IMAGE = 0x7A02
        private const val RC_CAPTURE_PHOTO = 0x7A03
    }

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
                    "appVersion" -> {
                        try {
                            val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                packageManager.getPackageInfo(
                                    packageName,
                                    android.content.pm.PackageManager.PackageInfoFlags.of(0),
                                )
                            } else {
                                @Suppress("DEPRECATION")
                                packageManager.getPackageInfo(packageName, 0)
                            }
                            result.success(info.versionName ?: "")
                        } catch (_: Exception) {
                            result.success("")
                        }
                    }
                    "localTimezone" -> {
                        try {
                            result.success(java.util.TimeZone.getDefault().id)
                        } catch (_: Exception) {
                            result.success(null)
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
                    "shareText" -> {
                        try {
                            val send = Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                putExtra(Intent.EXTRA_TEXT, call.argument<String>("text"))
                            }
                            startActivity(Intent.createChooser(send, null))
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                    "shareFile" -> {
                        try {
                            val file = File(call.argument<String>("path")!!)
                            val uri = FileProvider.getUriForFile(
                                this,
                                "${packageName}.fileprovider",
                                file,
                            )
                            val send = Intent(Intent.ACTION_SEND).apply {
                                type = call.argument<String>("mimeType")
                                    ?: "application/octet-stream"
                                putExtra(Intent.EXTRA_STREAM, uri)
                                putExtra(
                                    Intent.EXTRA_SUBJECT,
                                    call.argument<String>("subject"),
                                )
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            startActivity(Intent.createChooser(send, null))
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                    "pickFile" -> {
                        pendingPick = result
                        startActivityForResult(
                            Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "*/*"
                            },
                            RC_PICK_FILE,
                        )
                    }
                    "pickImage" -> {
                        pendingPick = result
                        startActivityForResult(
                            Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "image/*"
                            },
                            RC_PICK_IMAGE,
                        )
                    }
                    "capturePhoto" -> {
                        try {
                            val photo = File(
                                cacheDir,
                                "camera_${System.currentTimeMillis()}.jpg",
                            )
                            capturePhotoPath = photo.absolutePath
                            val uri = FileProvider.getUriForFile(
                                this,
                                "${packageName}.fileprovider",
                                photo,
                            )
                            val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
                                .apply {
                                    putExtra(MediaStore.EXTRA_OUTPUT, uri)
                                    addFlags(
                                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                            Intent.FLAG_GRANT_READ_URI_PERMISSION
                                    )
                                }
                            if (intent.resolveActivity(packageManager) != null) {
                                pendingPick = result
                                startActivityForResult(intent, RC_CAPTURE_PHOTO)
                            } else {
                                capturePhotoPath = null
                                result.success(null)
                            }
                        } catch (_: Exception) {
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        val res = pendingPick ?: return
        pendingPick = null
        when (requestCode) {
            RC_PICK_FILE, RC_PICK_IMAGE -> {
                val uri = data?.data
                res.success(
                    if (resultCode == Activity.RESULT_OK && uri != null) {
                        copyToCache(uri)
                    } else {
                        null
                    },
                )
            }
            RC_CAPTURE_PHOTO -> {
                val path = capturePhotoPath
                capturePhotoPath = null
                res.success(
                    if (resultCode == Activity.RESULT_OK && path != null &&
                        File(path).length() > 0
                    ) path else null,
                )
            }
            else -> Unit
        }
    }

    private fun copyToCache(uri: Uri): String? {
        return try {
            val name = displayName(uri) ?: "picked_${System.currentTimeMillis()}"
            val dest = File(cacheDir, name)
            contentResolver.openInputStream(uri)?.use { input ->
                dest.outputStream().use { input.copyTo(it) }
            }
            dest.absolutePath
        } catch (_: Exception) {
            null
        }
    }

    private fun displayName(uri: Uri): String? {
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (idx >= 0 && cursor.moveToFirst()) {
                val name = cursor.getString(idx)
                if (!name.isNullOrBlank()) return name.substringAfterLast('/')
            }
        }
        return null
    }
}
