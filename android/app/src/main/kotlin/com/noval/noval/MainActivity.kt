package com.noval.noval

import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "noval/update"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrEmpty()) {
                            result.error("bad_args", "path 为空", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val apk = File(path)
                            if (!apk.exists()) {
                                result.error("missing", "APK 不存在: $path", null)
                                return@setMethodCallHandler
                            }
                            val uri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                                FileProvider.getUriForFile(this, "$packageName.fileprovider", apk)
                            } else {
                                Uri.fromFile(apk)
                            }
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            startActivity(intent)
                            result.success("已打开系统安装器")
                        } catch (e: Exception) {
                            result.error("install_failed", e.message ?: "安装失败", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
