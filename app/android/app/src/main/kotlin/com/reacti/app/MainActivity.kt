package com.reacti.app

import android.content.Context
import android.media.AudioManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.camerax.FrontVideoMirror

// FlutterFragmentActivity, not FlutterActivity: local_auth's Android
// implementation needs a FragmentActivity to host the BiometricPrompt, and
// throws at runtime without one.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // After super, which registers the plugins: a selfie video can then be
        // recorded the way the preview showed it (lib/.../logic/selfie_mirror.dart).
        FrontVideoMirror.install(flutterEngine)
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
        // One-time media is on screen: no screenshots, no screen recording, and a
        // blank tile in recent apps while it is (lib/helpers/secure_screen.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "reacti/secure_screen")
            .setMethodCallHandler { call, result ->
                if (call.method == "setSecure") {
                    if (call.arguments == true) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
