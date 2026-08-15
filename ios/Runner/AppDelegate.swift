import AVFAudio
import CallKit
import Flutter
import Foundation
import PushKit
import UIKit
import UserNotifications
import WebRTC
import flutter_callkit_incoming

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, PKPushRegistryDelegate, CallkitIncomingAppDelegate {
  private static let pendingAcceptedCallKey = "pending_accepted_call"
  private var pushChannel: FlutterMethodChannel?
  private var clipboardChannel: FlutterMethodChannel?
  private var apnsTokenHex: String?
  private var voipRegistry: PKPushRegistry?

  // A VoIP push can arrive before the implicit Flutter engine has finished
  // spinning up (and thus before GeneratedPluginRegistrant.register has run
  // and SwiftFlutterCallkitIncomingPlugin.sharedInstance is set). In that
  // window, buffer the payload+completion here instead of dropping the call,
  // and replay it as soon as didInitializeImplicitFlutterEngine fires.
  private var pendingVoipPush: (payload: PKPushPayload, completion: () -> Void)?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    // NOTE: setupPushBridge(registry: self) below calls self.registrar(forPlugin:),
    // which lazily creates and runs the implicit Flutter engine synchronously
    // (FlutterAppDelegate -> FlutterLaunchEngine.engine getter), which in turn
    // triggers didInitializeImplicitFlutterEngine() and GeneratedPluginRegistrant
    // .register() before this method returns. That means SwiftFlutterCallkit
    // IncomingPlugin.sharedInstance is already set by the time setupVoipRegistry()
    // runs below and PushKit can start delivering pushes. The buffer-and-replay
    // logic further down is defense-in-depth in case that ordering ever changes.
    setupPushBridge(registry: self)
    setupClipboardBridge(registry: self)
    setupVoipRegistry()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func setupVoipRegistry() {
    let registry = PKPushRegistry(queue: .main)
    registry.delegate = self
    registry.desiredPushTypes = [.voIP]
    voipRegistry = registry
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Foundation.Data
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
    setupClipboardBridge(registry: engineBridge.pluginRegistry)
    flushPendingVoipPush()
  }

  // MARK: - CallKit/WebRTC audio bridge

  // flutter_callkit_incoming owns AVAudioSession while CallKit is active.
  // Forward its activation callbacks to libwebrtc so the WebRTC audio unit
  // starts using the already-active session.
  func didActivateAudioSession(_ audioSession: AVAudioSession) {
    RTCAudioSession.sharedInstance().audioSessionDidActivate(audioSession)
    RTCAudioSession.sharedInstance().isAudioEnabled = true
  }

  func didDeactivateAudioSession(_ audioSession: AVAudioSession) {
    RTCAudioSession.sharedInstance().audioSessionDidDeactivate(audioSession)
    RTCAudioSession.sharedInstance().isAudioEnabled = false
  }

  // Persist and forward native acceptance here because the plugin event
  // channel has no cold-start buffering. Media readiness is still reported
  // separately from the peer-connection callback.
  func onAccept(_ call: Call, _ action: CXAnswerCallAction) {
    let extra = call.data.extra
    let acceptedCall: [String: Any] = [
      "call_id": call.data.uuid,
      "caller_id": extra["caller_id"] as? String ?? "",
      "caller_display_name": call.data.nameCaller,
      "call_type": extra["call_type"] as? String ?? (call.data.type == 1 ? "video" : "voice"),
    ]
    // Persist before fulfilling the native action. Event-channel messages are
    // not buffered during a cold Flutter launch, while UserDefaults survives
    // until Dart explicitly consumes this acceptance.
    UserDefaults.standard.set(acceptedCall, forKey: Self.pendingAcceptedCallKey)
    pushChannel?.invokeMethod("callkitAccepted", arguments: acceptedCall)
    action.fulfill()
  }

  func onDecline(_ call: Call, _ action: CXEndCallAction) {
    clearPendingAcceptedCall(call.data.uuid)
    action.fulfill()
  }

  func onEnd(_ call: Call, _ action: CXEndCallAction) {
    clearPendingAcceptedCall(call.data.uuid)
    action.fulfill()
  }

  func onTimeOut(_ call: Call) {
    clearPendingAcceptedCall(call.data.uuid)
  }

  func providerDidReset() {
    UserDefaults.standard.removeObject(forKey: Self.pendingAcceptedCallKey)
  }

  // MARK: - PushKit (VoIP)

  func pushRegistry(
    _ registry: PKPushRegistry,
    didUpdate pushCredentials: PKPushCredentials,
    for type: PKPushType
  ) {
    guard type == .voIP else { return }
    let token = pushCredentials.token.map { String(format: "%02.2hhx", $0) }.joined()
    UserDefaults.standard.set(token, forKey: "voip_push_token")
    if let plugin = SwiftFlutterCallkitIncomingPlugin.sharedInstance {
      plugin.setDevicePushTokenVoIP(token)
    } else {
      NSLog("[VoIP] token updated but plugin.sharedInstance is nil; stored to UserDefaults only")
    }
  }

  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    guard type == .voIP else { return }
    UserDefaults.standard.removeObject(forKey: "voip_push_token")
  }

  func pushRegistry(
    _ registry: PKPushRegistry,
    didReceiveIncomingPushWith payload: PKPushPayload,
    for type: PKPushType,
    completion: @escaping () -> Void
  ) {
    guard type == .voIP else {
      completion()
      return
    }
    // CRITICAL (Apple hard requirement): completion() must be called for every
    // VoIP push, synchronously reporting a call via CallKit before returning —
    // failing to do so within the callback gets the app killed/penalized.
    // reportIncomingCall(...) below guarantees completion() is always invoked,
    // either immediately or after buffering for plugin registration.
    reportIncomingCall(from: payload, completion: completion)
  }

  private func reportIncomingCall(from payload: PKPushPayload, completion: @escaping () -> Void) {
    guard let plugin = SwiftFlutterCallkitIncomingPlugin.sharedInstance else {
      NSLog("[VoIP] plugin not registered yet; buffering incoming push for replay")
      pendingVoipPush = (payload, completion)
      return
    }
    showCallkit(payload: payload, plugin: plugin, completion: completion)
  }

  private func flushPendingVoipPush() {
    guard let pending = pendingVoipPush else { return }
    pendingVoipPush = nil
    guard let plugin = SwiftFlutterCallkitIncomingPlugin.sharedInstance else {
      // Should not happen — plugin registration just completed above — but
      // never leave a buffered push without calling its completion handler.
      NSLog("[VoIP] plugin still nil after registration; dropping buffered push")
      pending.completion()
      return
    }
    showCallkit(payload: pending.payload, plugin: plugin, completion: pending.completion)
  }

  private func showCallkit(
    payload: PKPushPayload,
    plugin: SwiftFlutterCallkitIncomingPlugin,
    completion: @escaping () -> Void
  ) {
    let userInfo = payload.dictionaryPayload
    let callId = userInfo["call_id"] as? String ?? UUID().uuidString
    let callerId = userInfo["caller_id"] as? String ?? ""
    // The server's VoIP payload names this field `caller_display_name`
    // (see apns_service::send_voip_call_push_to_tokens). Reading `caller_name`
    // never matched, so CallKit fell back to showing the caller's raw UUID.
    // `caller_name` is still accepted as a fallback for older payloads.
    let rawCallerName = (userInfo["caller_display_name"] as? String)
      ?? (userInfo["caller_name"] as? String)
      ?? ""
    let trimmedCallerName = rawCallerName.trimmingCharacters(in: .whitespacesAndNewlines)
    let callerName = trimmedCallerName.isEmpty ? "Unknown" : trimmedCallerName
    let callType = userInfo["call_type"] as? String ?? "voice"

    let args: [String: Any?] = [
      "id": callId,
      "nameCaller": callerName,
      "appName": "Sync",
      // Show the display name here too — `handle` surfaces in the CallKit UI
      // and in the system call history, and a raw UUID is meaningless there.
      // The caller's id is still carried in `extra.caller_id` for the app.
      "handle": callerName,
      "type": callType == "video" ? 1 : 0,
      "extra": [
        "call_id": callId,
        "caller_id": callerId,
        "call_type": callType,
      ],
      "ios": [
        "supportsVideo": true,
        "iconName": "CallKitLogo",
      ],
    ]
    let data = flutter_callkit_incoming.Data(args: args)
    plugin.showCallkitIncoming(data, fromPushKit: true, completion: completion)
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
      case "getPushTokenVoip":
        result(UserDefaults.standard.string(forKey: "voip_push_token"))
      case "showLocalNotification":
        self.showLocalNotification(call: call, result: result)
      case "getPendingCallNotification":
        let data = UserDefaults.standard.dictionary(forKey: "pending_call_notification")
        UserDefaults.standard.removeObject(forKey: "pending_call_notification")
        result(data)
      case "getPendingAcceptedCall":
        let data = UserDefaults.standard.dictionary(forKey: Self.pendingAcceptedCallKey)
        UserDefaults.standard.removeObject(forKey: Self.pendingAcceptedCallKey)
        result(data)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    pushChannel = channel
  }

  private func clearPendingAcceptedCall(_ callId: String) {
    let pending = UserDefaults.standard.dictionary(forKey: Self.pendingAcceptedCallKey)
    if pending?["call_id"] as? String == callId {
      UserDefaults.standard.removeObject(forKey: Self.pendingAcceptedCallKey)
    }
  }

  private func setupClipboardBridge(registry: FlutterPluginRegistry) {
    guard clipboardChannel == nil else { return }
    guard let registrar = registry.registrar(forPlugin: "ClipboardBridgePlugin") else { return }

    let channel = FlutterMethodChannel(
      name: "sync.clipboard",
      binaryMessenger: registrar.messenger()
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "unavailable", message: "App delegate missing", details: nil))
        return
      }

      switch call.method {
      case "copyPngToClipboard":
        self.copyPngToClipboard(call: call, result: result)
      case "readPngFromClipboard":
        self.readPngFromClipboard(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    clipboardChannel = channel
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

  private func copyPngToClipboard(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let typedData = call.arguments as? FlutterStandardTypedData else {
      result(
        FlutterError(
          code: "invalid_args",
          message: "Expected PNG bytes",
          details: nil
        )
      )
      return
    }

    DispatchQueue.main.async {
      UIPasteboard.general.setData(typedData.data, forPasteboardType: "public.png")
      result(nil)
    }
  }

  private func readPngFromClipboard(result: @escaping FlutterResult) {
    // UIPasteboard must be accessed on the main thread.
    DispatchQueue.main.async {
      let rawPngData = UIPasteboard.general.data(forPasteboardType: "public.png")
      let pasteboardImage = UIPasteboard.general.image

      // Resize/compress on a background thread to avoid blocking the UI.
      DispatchQueue.global(qos: .userInitiated).async {
        var image: UIImage? = nil
        if let data = rawPngData {
          image = UIImage(data: data)
        }
        if image == nil, let img = pasteboardImage {
          image = img
        }
        guard let image = image else {
          DispatchQueue.main.async { result(nil) }
          return
        }
        let resized = self.resizeImageIfNeeded(image, maxDimension: 1200)
        // Prefer JPEG for photos — vastly smaller than PNG for the same visual quality.
        let data = resized.jpegData(compressionQuality: 0.75) ?? resized.pngData()
        DispatchQueue.main.async {
          if let data = data {
            result(FlutterStandardTypedData(bytes: data))
          } else {
            result(nil)
          }
        }
      }
    }
  }

  private func resizeImageIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
    let size = image.size
    guard size.width > maxDimension || size.height > maxDimension else {
      return image
    }
    let ratio = min(maxDimension / size.width, maxDimension / size.height)
    let newSize = CGSize(
      width: (size.width * ratio).rounded(),
      height: (size.height * ratio).rounded()
    )
    let renderer = UIGraphicsImageRenderer(size: newSize)
    return renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: newSize))
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

  private func imageFileExtension(data: Foundation.Data) -> String {
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
    let userInfo = response.notification.request.content.userInfo
    if let callId = userInfo["call_id"] as? String, !callId.isEmpty {
      UserDefaults.standard.set(
        [
          "call_id": callId,
          "caller_id": userInfo["caller_id"] as? String ?? "",
          "call_type": userInfo["call_type"] as? String ?? "voice",
        ],
        forKey: "pending_call_notification"
      )
    }
    completionHandler()
  }
}
