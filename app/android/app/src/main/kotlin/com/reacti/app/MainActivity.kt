package com.reacti.app

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
    }
}
