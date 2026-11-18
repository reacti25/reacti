package com.reacti.app;

import android.Manifest;
import androidx.test.rule.ActivityTestRule;
import androidx.test.runner.permission.PermissionRequester;
import dev.flutter.plugins.integration_test.FlutterTestRunner;
import org.junit.Rule;
import org.junit.runner.RunWith;

/**
 * Wraps the Dart integration tests (app/integration_test/) as an Android instrumentation test,
 * the only form Google's device lab (Firebase Test Lab) can run on a real phone. Built and sent
 * there by .github/workflows/android-real-phones.yml.
 *
 * <p>The emulator checks do not use this class: they run through {@code flutter test}, with the
 * host granting permissions over adb (.github/scripts/android_integration.sh).
 */
@RunWith(FlutterTestRunner.class)
public class MainActivityTest {
  /** The activity the Dart tests run in; {@link FlutterTestRunner} launches it. */
  @Rule
  public ActivityTestRule<MainActivity> rule =
      new ActivityTestRule<>(MainActivity.class, true, false);

  /**
   * Grants the camera and the microphone before the app starts: nobody is at a lab phone to tap
   * "Allow", and the tests wait for both. Done here, not with a GrantPermissionRule, because
   * FlutterTestRunner applies no rule except the activity one; it does build this class before it
   * launches the activity.
   */
  public MainActivityTest() {
    PermissionRequester requester = new PermissionRequester();
    requester.addPermissions(Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO);
    requester.requestPermissions();
  }
}
