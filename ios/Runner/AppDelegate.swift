import Flutter
import Foundation
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
      case "showLocalNotification":
        self.showLocalNotification(call: call, result: result)
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

  private func showLocalNotification(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      result(
        FlutterError(
          code: "invalid_args",
          message: "Expected title/body arguments",
          details: nil
        )
      )
      return
    }

    let title = (args["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let body = (args["body"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let avatarBase64 = (args["avatarBase64"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    if title.isEmpty && body.isEmpty {
      result(nil)
      return
    }

    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    if let avatarBase64, !avatarBase64.isEmpty {
      if let attachment = makeAvatarAttachment(base64: avatarBase64) {
        content.attachments = [attachment]
      }
    }

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
    let request = UNNotificationRequest(
      identifier: UUID().uuidString,
      content: content,
      trigger: trigger
    )
    UNUserNotificationCenter.current().add(request) { error in
      if let error {
        result(
          FlutterError(
            code: "notification_error",
            message: "Failed to show local notification",
            details: error.localizedDescription
          )
        )
        return
      }
      result(nil)
    }
  }

  private func makeAvatarAttachment(base64: String) -> UNNotificationAttachment? {
    guard let data = Data(base64Encoded: base64, options: [.ignoreUnknownCharacters]) else {
      return nil
    }
    let fileExtension = imageFileExtension(data: data)
    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    let fileUrl = tempDir.appendingPathComponent("sync_avatar_\(UUID().uuidString).\(fileExtension)")
    do {
      try data.write(to: fileUrl, options: [.atomic])
      return try UNNotificationAttachment(identifier: UUID().uuidString, url: fileUrl)
    } catch {
      return nil
    }
  }

  private func imageFileExtension(data: Data) -> String {
    let bytes = [UInt8](data.prefix(12))
    if bytes.count >= 8 &&
      bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 &&
      bytes[4] == 0x0D && bytes[5] == 0x0A && bytes[6] == 0x1A && bytes[7] == 0x0A {
      return "png"
    }
    if bytes.count >= 3 &&
      bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
      return "jpg"
    }
    return "png"
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Suppress the remote APNs banner while the app is foregrounded — the
    // WebSocket connection already delivers the message and triggers a local
    // notification, so showing both would produce a duplicate banner.
    let isRemote = notification.request.trigger is UNPushNotificationTrigger
    if isRemote {
      completionHandler([])
    } else {
      if #available(iOS 14.0, *) {
        completionHandler([.banner, .list, .sound, .badge])
      } else {
        completionHandler([.alert, .sound, .badge])
      }
    }
  }

  // Required so iOS knows we handled the response when the user taps a
  // notification while the app is in the background or terminated state.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    completionHandler()
  }
}
