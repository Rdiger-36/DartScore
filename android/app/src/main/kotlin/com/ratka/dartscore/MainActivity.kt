package com.ratka.dartscore

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale

/**
 * Hosts the Flutter engine and adds the things this app needs from the platform
 * directly: the system document picker, what this device calls itself, and the
 * Wi-Fi network a transfer can raise for itself.
 *
 * Written by hand instead of taken from a package because every file picking
 * plugin still wants CocoaPods on the iOS side, which this project deliberately
 * does not use. The iOS halves live in `DocumentPickerHandler.swift`,
 * `DeviceDescriptionHandler.swift` and `HotspotJoinHandler.swift`; the hotspot
 * itself has no iOS half, because Apple gives no app a way to raise a network.
 */
class MainActivity : FlutterActivity() {
    /** Shared with `DocumentPicker` on the Dart side. */
    private val channelName = "dartscore/document_picker"

    /** Shared with `DeviceDescription` on the Dart side. */
    private val deviceChannelName = "dartscore/device_description"

    /** Shared with `IncomingFiles` on the Dart side. */
    private val incomingChannelName = "dartscore/incoming_file"

    private val requestPickFile = 0x0BAC

    /** The call waiting for the user to pick something, or null when idle. */
    private var pending: MethodChannel.Result? = null

    /** Raises and joins the Wi-Fi network a transfer can run over. */
    private val hotspot by lazy { LocalHotspotHandler(this) }

    /** Channel the opened file is announced on, once Dart is listening. */
    private var incomingChannel: MethodChannel? = null

    /**
     * A file this app was launched with, waiting to be asked for.
     *
     * The intent arrives before there is any Dart to hand it to, so it is kept
     * until `initial` comes to collect it. Handing it over clears it: a file is
     * offered once, not again on the next rebuild.
     */
    private var pendingIncoming: String? = null

    /**
     * Whether Dart has asked for its first file yet.
     *
     * The channel existing is not the same as somebody listening on it: it is
     * set up while the engine is being configured, before any widget has
     * attached a handler. The first `initial` call is what says the other end
     * is there, and until it comes everything waits.
     */
    private var incomingReady = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickFile" -> pickFile(result)
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "describe" -> result.success(describeDevice())
                    else -> result.notImplemented()
                }
            }
        incomingChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, incomingChannelName
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "initial" -> {
                        incomingReady = true
                        result.success(pendingIncoming)
                        pendingIncoming = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
        hotspot.attach(flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        pendingIncoming = copyIncoming(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val path = copyIncoming(intent) ?: return
        // Dart is up by now, so the file goes straight over rather than waiting
        // to be collected.
        val channel = incomingChannel
        if (!incomingReady || channel == null) {
            pendingIncoming = path
        } else {
            channel.invokeMethod("opened", path)
        }
    }

    /**
     * Copies whatever a view intent points at into this app's cache and returns
     * the path, or null when the intent carries no file.
     *
     * Copied rather than read where it lies, like the document picker beside
     * it: what arrives is a `content://` URI belonging to another app, granted
     * for this one launch, and nothing above this works on anything but paths.
     */
    private fun copyIncoming(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_VIEW) return null
        val uri = intent.data ?: return null
        return try {
            copyToCache(uri).absolutePath
        } catch (e: Exception) {
            null
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        hotspot.onRequestPermissionsResult(requestCode, grantResults)
    }

    /**
     * Nothing about a transfer survives the screen it ran on.
     *
     * A hotspot left up costs battery and confuses anyone looking at their
     * Wi-Fi list, and a process still bound to a network that is gone has no
     * route to anything at all.
     */
    override fun onDestroy() {
        hotspot.stopHotspot()
        hotspot.leave()
        super.onDestroy()
    }

    /**
     * What to call this device, and which Android it runs.
     *
     * Prefers the name the owner gave the device in its settings, because that
     * is what they will recognise on the other end of a transfer. It is not
     * always set and not readable on every build, so the manufacturer and model
     * stand in, which is a part code rather than a name but still tells two
     * devices apart.
     */
    private fun describeDevice(): Map<String, String> = mapOf(
        "name" to (userAssignedName() ?: modelName()),
        "os" to "Android ${Build.VERSION.RELEASE}",
    )

    /** The name from the device settings, or null when there is none to read. */
    private fun userAssignedName(): String? = try {
        Settings.Global.getString(contentResolver, Settings.Global.DEVICE_NAME)
            ?.trim()
            ?.ifEmpty { null }
    } catch (e: Exception) {
        null
    }

    /** Manufacturer and model, without repeating the manufacturer twice. */
    private fun modelName(): String {
        val manufacturer = Build.MANUFACTURER.orEmpty()
        val model = Build.MODEL.orEmpty()
        if (model.startsWith(manufacturer, ignoreCase = true)) return model
        val prefix = manufacturer.replaceFirstChar {
            if (it.isLowerCase()) it.titlecase(Locale.getDefault()) else it.toString()
        }
        return "$prefix $model".trim()
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
