// Lives in the camera plugin's own package on purpose: it extends a
// package-private class of camera_android_camerax and reads its registrar.
// If a plugin upgrade renames either, this file stops compiling and the
// "Build Android" check fails, which is the wanted alarm.
package io.flutter.plugins.camerax;

import android.util.Range;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.camera.core.MirrorMode;
import androidx.camera.video.VideoCapture;
import androidx.camera.video.VideoOutput;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;

/**
 * Makes a front-camera video come out the way the preview showed it.
 *
 * <p>The preview of a front lens is a mirror, but CameraX records the video un-mirrored unless
 * told otherwise, so a selfie video jumped to the other side once it was recorded. CameraX has the
 * switch for this ({@link MirrorMode#MIRROR_MODE_ON_FRONT_ONLY}); the camera plugin simply never
 * sets it and offers no option to. This class takes the plugin's place for the one call that
 * builds the video recorder and sets the switch there. Nothing is re-encoded, so the video keeps
 * its quality and is ready as fast as before. Back-lens video is never mirrored by this mode.
 *
 * <p>Off by default and switched from Dart over the {@code reacti/front_video_mirror} channel
 * ({@code setFrontVideoMirrored} in {@code selfie_mirror.dart}), so only the in-app camera screen
 * turns it on. The silent reaction recorder builds its camera while this is off and records
 * exactly as it did before.
 */
public final class FrontVideoMirror extends VideoCaptureProxyApi {
  /** Name of the channel Dart uses to switch the mirroring on and off. */
  private static final String CHANNEL = "reacti/front_video_mirror";

  /** Whether the next camera that is built should mirror its front-lens video. */
  private volatile boolean enabled = false;

  private FrontVideoMirror(@NonNull ProxyApiRegistrar registrar) {
    super(registrar);
  }

  /**
   * Puts this class in charge of building the plugin's video recorder on {@code engine} and opens
   * the channel that switches the mirroring.
   *
   * <p>Call after the plugins are registered. Does nothing when the camera plugin is not attached,
   * in which case video records un-mirrored as before.
   */
  public static void install(@NonNull FlutterEngine engine) {
    final CameraAndroidCameraxPlugin plugin =
        (CameraAndroidCameraxPlugin) engine.getPlugins().get(CameraAndroidCameraxPlugin.class);
    if (plugin == null || plugin.proxyApiRegistrar == null) {
      return;
    }
    final FrontVideoMirror mirror = new FrontVideoMirror(plugin.proxyApiRegistrar);
    final BinaryMessenger messenger = engine.getDartExecutor().getBinaryMessenger();
    // The same call the plugin makes when it registers; the last handler set is the one used.
    PigeonApiVideoCapture.Companion.setUpMessageHandlers(messenger, mirror);
    new MethodChannel(messenger, CHANNEL)
        .setMethodCallHandler(
            (call, result) -> {
              if (call.method.equals("setEnabled")) {
                mirror.enabled = Boolean.TRUE.equals(call.arguments);
                result.success(null);
              } else {
                result.notImplemented();
              }
            });
  }

  /**
   * Builds the video recorder, mirrored on the front lens while the mirroring is switched on.
   *
   * <p>ponytail: a camera opened with a fixed frame rate takes the plugin's own path and is not
   * mirrored, because that path carries extra setup this class does not repeat. The app never asks
   * for a fixed frame rate; handle it here if it ever does.
   */
  @NonNull
  @Override
  public VideoCapture<?> withOutput(
      @NonNull VideoOutput videoOutput, @Nullable Range<?> targetFpsRange) {
    if (!enabled || targetFpsRange != null) {
      return super.withOutput(videoOutput, targetFpsRange);
    }
    return new VideoCapture.Builder<>(videoOutput)
        .setMirrorMode(MirrorMode.MIRROR_MODE_ON_FRONT_ONLY)
        .build();
  }
}
