package com.reacti.app

import android.content.Context
import android.media.AudioManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity, not FlutterActivity: local_auth's Android
// implementation needs a FragmentActivity to host the BiometricPrompt, and
// throws at runtime without one.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Google's test lab (Play pre-launch reports) sets this; analytics stays off there.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "reacti/test_lab")
            .setMethodCallHandler { call, result ->
                if (call.method == "isTestLab") {
                    result.success(Settings.System.getString(contentResolver, "firebase.test.lab") == "true")
                } else {
                    result.notImplemented()
                }
            }
        // A call holds the mic, so sealed media must not open during one
        // (lib/helpers/call_status.dart). IN_CALL = phone call,
        // IN_COMMUNICATION = WhatsApp and other VoIP calls. No permission needed.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "reacti/call_status")
            .setMethodCallHandler { call, result ->
                if (call.method == "isInCall") {
                    val mode = (getSystemService(Context.AUDIO_SERVICE) as AudioManager).mode
                    result.success(mode == AudioManager.MODE_IN_CALL || mode == AudioManager.MODE_IN_COMMUNICATION)
                } else {
                    result.notImplemented()
                }
            }
    }
}
