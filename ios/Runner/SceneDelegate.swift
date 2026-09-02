import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

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