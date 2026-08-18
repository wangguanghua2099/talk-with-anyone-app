package com.talkwithanyone.talk_with_anyone_app

import android.Manifest
import android.content.ContentValues
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.talkwithanyone/save"
        private const val REQ_WRITE_STORAGE = 1001
    }

    private var pendingResult: MethodChannel.Result? = null
    private var pendingFileName: String? = null
    private var pendingMimeType: String? = null
    private var pendingBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveFile" -> {
                        val fileName = call.argument<String>("fileName")
                        val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                        val bytes = call.argument<ByteArray>("bytes")
                        if (fileName == null || bytes == null) {
                            result.error("bad_args", "fileName and bytes are required", null)
                        } else {
                            saveToDownloads(fileName, mimeType, bytes, result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun saveToDownloads(fileName: String, mimeType: String, bytes: ByteArray, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+（API 29+）：MediaStore 写公共 Downloads，无需存储权限
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            }
            val resolver = contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            if (uri != null) {
                try {
                    resolver.openOutputStream(uri)?.use { it.write(bytes) }
                    result.success("Download/$fileName")
                    return
                } catch (e: Exception) {
                    resolver.delete(uri, null, null)
                    result.error("save_failed", e.message, null)
                    return
                }
            }
            result.error("save_failed", "Failed to create file in Downloads", null)
            return
        }

        // Android 9 及以下（API ≤ 28）：需要 WRITE_EXTERNAL_STORAGE 运行时权限
        if (checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
            pendingResult = result
            pendingFileName = fileName
            pendingMimeType = mimeType
            pendingBytes = bytes
            requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), REQ_WRITE_STORAGE)
            return
        }
        writeLegacy(fileName, bytes, result)
    }

    private fun writeLegacy(fileName: String, bytes: ByteArray, result: MethodChannel.Result) {
        try {
            val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!dir.exists()) dir.mkdirs()
            val file = File(dir, fileName)
            file.writeBytes(bytes)
            result.success(file.absolutePath)
        } catch (e: Exception) {
            result.error("save_failed", e.message, null)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQ_WRITE_STORAGE) return
        val result = pendingResult
        val fileName = pendingFileName
        val mimeType = pendingMimeType
        val bytes = pendingBytes
        pendingResult = null
        pendingFileName = null
        pendingMimeType = null
        pendingBytes = null
        if (result != null && fileName != null && bytes != null) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                writeLegacy(fileName, bytes, result)
            } else {
                result.error("permission_denied", "存储权限被拒绝", null)
            }
        }
    }
}
