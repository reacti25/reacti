import CallKit
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Sees every call CallKit knows: cellular, FaceTime, WhatsApp and other VoIP apps.
  private let callObserver = CXCallObserver()

  /// While one-time media is open: the password field the app is drawn inside
  /// (see setSecure), and where the app's layer goes back to afterwards.
  private var secureField: UITextField?
  private weak var appLayerHome: CALayer?

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
    // One-time media (lib/helpers/secure_screen.dart): kept out of screenshots
    // and screen recordings while open (setSecure), and every screenshot is
    // still reported, so the chat can tell the sender someone tried.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ReactiSecureScreen") {
      let channel = FlutterMethodChannel(name: "reacti/secure_screen", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "setSecure":
          self?.setSecure(call.arguments as? Bool == true)
          result(nil)
        // Read back by the device lab (integration_test/one_time_media_test.dart).
        case "isSecure":
          result(self?.secureField != nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      NotificationCenter.default.addObserver(
        forName: UIApplication.userDidTakeScreenshotNotification, object: nil, queue: .main
      ) { _ in
        channel.invokeMethod("screenshot", arguments: nil)
      }
    }
  }

  /// Keeps the app out of screenshots and screen recordings while [on].
  ///
  /// iOS has no setting for this. The known way, the one WhatsApp's view-once
  /// uses, is to draw the app inside the layer of a password field: iOS leaves
  /// that layer blank in every capture. So the window's layer moves into it,
  /// and moves back to exactly where it was when [on] is false. Only while
  /// one-time media is open, so the rest of the app is never drawn this way.
  private func setSecure(_ on: Bool) {
    guard let window = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .flatMap({ $0.windows })
      .first(where: { $0.isKeyWindow }) else { return }
    if on {
      guard secureField == nil, let home = window.layer.superlayer,
        let index = home.sublayers?.firstIndex(of: window.layer) else { return }
      let field = UITextField()
      field.isSecureTextEntry = true
      field.isUserInteractionEnabled = false
      window.addSubview(field)
      field.layoutIfNeeded()
      // The capture-proof canvas is the field's first sublayer before iOS 17, its last since.
      let canvas: CALayer?
      if #available(iOS 17.0, *) {
        canvas = field.layer.sublayers?.last
      } else {
        canvas = field.layer.sublayers?.first
      }
      guard let canvas else {
        field.removeFromSuperview()
        return
      }
      home.insertSublayer(field.layer, at: UInt32(index))
      canvas.addSublayer(window.layer)
      secureField = field
      appLayerHome = home
    } else {
      guard let field = secureField else { return }
      if let home = appLayerHome, let index = home.sublayers?.firstIndex(of: field.layer) {
        home.insertSublayer(window.layer, at: UInt32(index))
      }
      field.removeFromSuperview()
      field.layer.removeFromSuperlayer()
      secureField = nil
    }
  }
}
