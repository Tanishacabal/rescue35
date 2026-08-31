import Flutter
import UIKit
import FirebaseAuth

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if Auth.auth().canHandle(url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Register the same 'rescue35/native_actions' MethodChannel used on
    // Android so calls like _callNumber() from Dart actually do something
    // on iOS instead of throwing a MissingPluginException.
    if let controller = engineBridge.pluginRegistry as? FlutterViewController {
      let nativeActionsChannel = FlutterMethodChannel(
        name: "rescue35/native_actions",
        binaryMessenger: controller.binaryMessenger
      )

      nativeActionsChannel.setMethodCallHandler { call, result in
        switch call.method {
        case "dial":
          guard
            let args = call.arguments as? [String: Any],
            let number = args["number"] as? String,
            !number.isEmpty
          else {
            result(FlutterError(
              code: "INVALID_ARGUMENT",
              message: "Missing or empty 'number'",
              details: nil
            ))
            return
          }

          let sanitized = number.trimmingCharacters(in: .whitespacesAndNewlines)
          guard let url = URL(string: "tel://\(sanitized)") else {
            result(FlutterError(
              code: "BAD_URL",
              message: "Could not build tel: URL from '\(number)'",
              details: nil
            ))
            return
          }

          if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:]) { success in
              result(success)
            }
          } else {
            result(FlutterError(
              code: "CANNOT_DIAL",
              message: "Device cannot open tel: URLs (e.g. iPad without cellular)",
              details: nil
            ))
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}