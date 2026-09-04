package com.reacti.app

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity, not FlutterActivity: local_auth's Android
// implementation needs a FragmentActivity to host the BiometricPrompt, and
// throws at runtime without one.
class MainActivity : FlutterFragmentActivity()
