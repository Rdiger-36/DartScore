package com.ratka.dartscore

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Hosts the Flutter engine and adds the one thing this app needs from the
 * platform directly: the system document picker.
 *
 * Written by hand instead of taken from a package because every file picking
 * plugin still wants CocoaPods on the iOS side, which this project deliberately
 * does not use. The iOS half of this lives in `DocumentPickerHandler.swift`.
 */
class MainActivity : FlutterActivity() {
    /** Shared with `DocumentPicker` on the Dart side. */
    private val channelName = "dartscore/document_picker"

    private val requestPickFile = 0x0BAC

    /** The call waiting for the user to pick something, or null when idle. */
    private var pending: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickFile" -> pickFile(result)
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Opens the storage access framework. It grants access to the one document
     * the user picks, so this needs no storage permission of any kind.
     */
    private fun pickFile(result: MethodChannel.Result) {
        if (pending != null) {
            result.success(null)
            return
        }
        pending = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            // A backup carries no type any provider agrees on, and a filter that
            // is too narrow greys the file out with no way to say why.
            type = "*/*"
        }
        startActivityForResult(intent, requestPickFile)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != requestPickFile) return

        val result = pending ?: return
        pending = null

        val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
        if (uri == null) {
            result.success(null)
            return
        }
        try {
            result.success(copyToCache(uri).absolutePath)
        } catch (e: Exception) {
            result.error("pick_failed", e.message, null)
        }
    }

    /**
     * Copies the picked document into the app's cache and returns the file.
     *
     * What the picker hands back is a `content://` URI from another app, which
     * nothing outside an Android content resolver can open. Everything above
     * this works on paths, so the document is streamed into a file this app
     * owns first.
     */
    private fun copyToCache(uri: Uri): File {
        val target = File(cacheDir, "picked-${displayName(uri)}")
        contentResolver.openInputStream(uri).use { input ->
            requireNotNull(input) { "cannot read $uri" }
            target.outputStream().use { input.copyTo(it) }
        }
        return target
    }

    /** The document's name as the provider reports it, stripped of any path. */
    private fun displayName(uri: Uri): String {
        val fallback = "backup.db"
        val cursor = contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
        cursor.use {
            if (it == null || !it.moveToFirst()) return fallback
            val index = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index < 0) return fallback
            val name = it.getString(index) ?: return fallback
            return name.substringAfterLast('/').ifEmpty { fallback }
        }
    }
}
