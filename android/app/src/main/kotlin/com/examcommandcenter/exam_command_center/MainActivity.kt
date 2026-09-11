package com.examcommandcenter.exam_command_center

import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.ArrayList

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.examcommandcenter.direct_share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getClipboardImage" -> {
                    try {
                        val clipboardManager = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                        val clip = clipboardManager.primaryClip
                        if (clip != null && clip.itemCount > 0) {
                            val item = clip.getItemAt(0)
                            val uri = item.uri
                            if (uri != null) {
                                contentResolver.openInputStream(uri)?.use { stream ->
                                    val bytes = stream.readBytes()
                                    if (bytes.isNotEmpty()) {
                                        result.success(bytes)
                                        return@setMethodCallHandler
                                    }
                                }
                            }
                            val text = item.text?.toString() ?: ""
                            if (text.startsWith("content://") || text.startsWith("file://")) {
                                val parsedUri = Uri.parse(text)
                                contentResolver.openInputStream(parsedUri)?.use { stream ->
                                    val bytes = stream.readBytes()
                                    if (bytes.isNotEmpty()) {
                                        result.success(bytes)
                                        return@setMethodCallHandler
                                    }
                                }
                            }
                        }
                        result.success(null)
                    } catch (e: Exception) {
                        result.success(null)
                    }
                }
                "readUriBytes" -> {
                    val uriStr = call.argument<String>("uri")
                    if (uriStr != null) {
                        try {
                            val parsedUri = Uri.parse(uriStr)
                            contentResolver.openInputStream(parsedUri)?.use { stream ->
                                val bytes = stream.readBytes()
                                result.success(bytes)
                                return@setMethodCallHandler
                            }
                        } catch (e: Exception) {
                            result.error("READ_ERROR", e.message, null)
                            return@setMethodCallHandler
                        }
                    }
                    result.success(null)
                }
                "shareImage" -> {
                val imagePaths = call.argument<List<String>>("imagePaths")
                val text = call.argument<String>("text")
                val packageName = call.argument<String>("package")

                if (imagePaths != null && imagePaths.isNotEmpty() && packageName != null) {
                    try {
                        val uris = ArrayList<Uri>()
                        for (path in imagePaths) {
                            val file = File(path)
                            val uri = FileProvider.getUriForFile(
                                this,
                                "com.examcommandcenter.exam_command_center.provider",
                                file
                            )
                            uris.add(uri)
                        }

                        val intent = if (uris.size == 1) {
                            Intent(Intent.ACTION_SEND).apply {
                                type = "image/*"
                                putExtra(Intent.EXTRA_STREAM, uris[0])
                            }
                        } else {
                            Intent(Intent.ACTION_SEND_MULTIPLE).apply {
                                type = "image/*"
                                putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
                            }
                        }

                        intent.apply {
                            if (text != null) {
                                putExtra(Intent.EXTRA_TEXT, text)
                            }
                            setPackage(packageName)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }

                        // Check if the target app is installed
                        if (intent.resolveActivity(packageManager) != null) {
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        result.error("SHARE_ERROR", e.message, null)
                    }
                } else {
                    result.error("INVALID_ARGS", "Missing imagePaths or package", null)
                }
                }
                else -> result.notImplemented()
            }
        }
    }
}
