import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var pushChannel: FlutterMethodChannel?
  private var apnsTokenHex: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    setupPushBridge(registry: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    apnsTokenHex = token
    UserDefaults.standard.set(token, forKey: "apns_push_token")
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("APNS registration failed: \(error.localizedDescription)")
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    setupPushBridge(registry: engineBridge.pluginRegistry)
  }

  private func setupPushBridge(registry: FlutterPluginRegistry) {
    guard pushChannel == nil else { return }
    guard let registrar = registry.registrar(forPlugin: "PushBridgePlugin") else { return }

    let channel = FlutterMethodChannel(
      name: "sync.notifications",
      binaryMessenger: registrar.messenger()
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "unavailable", message: "App delegate missing", details: nil))
        return
      }

      switch call.method {
      case "requestPushPermission":
        self.requestPushPermission(result: result)
      case "getPushToken":
        let token = self.apnsTokenHex ?? UserDefaults.standard.string(forKey: "apns_push_token")
        result(token)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    pushChannel = channel
  }

  private func requestPushPermission(result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .sound, .badge]
    ) { granted, error in
      if let error {
        result(
          FlutterError(
            code: "permission_error",
            message: "Failed to request notification permission",
            details: error.localizedDescription
          )
        )
        return
      }

      DispatchQueue.main.async {
        if granted {
          UIApplication.shared.registerForRemoteNotifications()
        }
        result(granted)
      }
    }
  }
}
