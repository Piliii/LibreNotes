package dev.librenotes.app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Handles the Android share sheet (`ACTION_SEND`) so text/links shared from
 * other apps can become a LibreNotes note. `singleTop` launch mode means a
 * share while the app is already running arrives via [onNewIntent] rather
 * than a fresh process, so both paths funnel into the same method channel
 * that the Dart-side `ShareIntentService` (lib/android/share_intent.dart)
 * listens on.
 */
class MainActivity : FlutterActivity() {
    private val shareChannelName = "dev.librenotes.app/share"
    private var shareChannel: MethodChannel? = null
    private var pendingSharedText: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingSharedText = extractSharedText(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, shareChannelName)
        shareChannel?.setMethodCallHandler { call, result ->
            if (call.method == "getInitialSharedText") {
                result.success(pendingSharedText)
                pendingSharedText = null
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val text = extractSharedText(intent)
        if (text != null) {
            shareChannel?.invokeMethod("onSharedText", text)
        }
    }

    private fun extractSharedText(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_SEND || intent.type != "text/plain") return null
        return intent.getStringExtra(Intent.EXTRA_TEXT)
    }
}
