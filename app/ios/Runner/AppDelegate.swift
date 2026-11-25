import CallKit
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Sees every call CallKit knows: cellular, FaceTime, WhatsApp and other VoIP apps.
  private let callObserver = CXCallObserver()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // A call holds the mic, so sealed media must not open during one (lib/helpers/call_status.dart).
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ReactiCallStatus") {
      FlutterMethodChannel(name: "reacti/call_status", binaryMessenger: registrar.messenger())
        .setMethodCallHandler { [weak self] call, result in
          guard call.method == "isInCall" else { return result(FlutterMethodNotImplemented) }
          result(self?.callObserver.calls.contains { !$0.hasEnded } ?? false)
        }
    }
    // One-time media (lib/helpers/secure_screen.dart). iOS has no switch that
    // blocks screenshots, so "setSecure" is accepted and does nothing here;
    // instead every screenshot is reported, and the chat tells the sender.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ReactiSecureScreen") {
      let channel = FlutterMethodChannel(name: "reacti/secure_screen", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { _, result in result(nil) }
      NotificationCenter.default.addObserver(
        forName: UIApplication.userDidTakeScreenshotNotification, object: nil, queue: .main
      ) { _ in
        channel.invokeMethod("screenshot", arguments: nil)
      }
    }
  }
}
