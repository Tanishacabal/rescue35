import Flutter
import UIKit
import FirebaseAuth

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as? FlutterViewController
    if let controller {
      let nativeActionsChannel = FlutterMethodChannel(
        name: "rescue35/native_actions",
        binaryMessenger: controller.binaryMessenger
      )

      nativeActionsChannel.setMethodCallHandler { [weak self] call, result in
        guard let self else {
          result(FlutterError(code: "NO_APP_DELEGATE", message: "App delegate unavailable", details: nil))
          return
        }

        self.handleNativeCall(call: call, result: result)
      }
    }

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

  private func handleNativeCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
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

      let sanitized = number
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "-", with: "")
      guard !sanitized.isEmpty else {
        result(FlutterError(
          code: "INVALID_ARGUMENT",
          message: "Phone number is empty after sanitization",
          details: nil
        ))
        return
      }

      let telURLString = "tel://\(sanitized)"
      let telPromptURLString = "telprompt://\(sanitized)"

      if let telURL = URL(string: telURLString), UIApplication.shared.canOpenURL(telURL) {
        UIApplication.shared.open(telURL, options: [:]) { success in
          result(success)
        }
        return
      }

      if let telPromptURL = URL(string: telPromptURLString), UIApplication.shared.canOpenURL(telPromptURL) {
        UIApplication.shared.open(telPromptURL, options: [:]) { success in
          result(success)
        }
        return
      }

      result(FlutterError(
        code: "CANNOT_DIAL",
        message: "This device cannot open tel URLs. Please ensure the phone app is available.",
        details: nil
      ))
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}