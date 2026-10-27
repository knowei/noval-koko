package com.noval.noval

import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

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
                            // 签名预检：签名和手机上已装的版本不一致时，系统安装器只会丢一句
                            // 「已安装了签名冲突的应用」，这里提前说清怎么办。
                            val installed = installedCertDigest()
                            val incoming = archiveCertDigest(apk)
                            if (installed != null && incoming != null && installed != incoming) {
                                result.error(
                                    "signature_mismatch",
                                    "这个安装包的签名和手机上已装的「墨町」不是同一把钥匙，"
                                        + "系统不允许覆盖安装。\n\n"
                                        + "处理办法：先卸载手机上的旧版（书架会丢，源可重新导入），"
                                        + "再装这一版；从下一版起应用内更新就不会再冲突了。",
                                    null,
                                )
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

    /** 当前已安装包的签名 SHA-256；拿不到就返回 null（不做判断）。 */
    private fun installedCertDigest(): String? = try {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            @Suppress("DEPRECATION")
            PackageManager.GET_SIGNATURES
        }
        digestOf(packageManager.getPackageInfo(packageName, flags))
    } catch (e: Exception) {
        null
    }

    /** APK 文件里的签名 SHA-256；解析失败返回 null。 */
    private fun archiveCertDigest(apk: File): String? = try {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            @Suppress("DEPRECATION")
            PackageManager.GET_SIGNATURES
        }
        @Suppress("DEPRECATION")
        val info = packageManager.getPackageArchiveInfo(apk.absolutePath, flags)
        if (info == null) null else digestOf(info)
    } catch (e: Exception) {
        null
    }

    @Suppress("DEPRECATION")
    private fun digestOf(info: PackageInfo): String? {
        val bytes: ByteArray? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val signing = info.signingInfo ?: return null
            val certs = signing.apkContentsSigners
            if (certs.isEmpty()) null else certs[0].toByteArray()
        } else {
            val sigs = info.signatures
            if (sigs.isNullOrEmpty()) null else sigs[0].toByteArray()
        } ?: return null
        val md = MessageDigest.getInstance("SHA-256")
        return md.digest(bytes).joinToString("") { "%02x".format(it) }
    }
}
