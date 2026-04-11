# iOS Push Notifications Setup

This document describes how iOS push notifications work in this project and how
to configure them end-to-end. The app supports two delivery modes:

- **Relay** (default) — the server forwards an encrypted payload to a
  publisher-hosted relay at `https://push.sync.icyanstudio.net` which holds the
  official APNs credentials and delivers the notification to iOS.
- **Direct** — your server sends the APNs request itself using credentials you
  supply.

If you are deploying a **community server** for the official app binary,
the relay mode requires no APNs credentials on your end — it works out of
the box.

---

## Prerequisites

- An Apple Developer account (paid, $99/year)
- Xcode with the project open at `mobile/ios/Runner.xcworkspace`
- The bundle ID registered in App Store Connect / Certificates, Identifiers &
  Profiles:  `com.icyanstudio.sync` (or your own if you forked the app)

---

## Part 1 — Xcode Project Configuration

These steps have already been completed for the official app. Document them
here so they can be reproduced if the project is regenerated or forked.

### 1.1 Enable Push Notifications capability

1. Open `Runner.xcworkspace` in Xcode.
2. Select the **Runner** target → **Signing & Capabilities** tab.
3. Click **+ Capability** and add **Push Notifications**.
4. Xcode will update `Runner.entitlements` automatically.

### 1.2 Verify `Runner.entitlements`

`mobile/ios/Runner/Runner.entitlements` must contain:

```xml
<key>aps-environment</key>
<string>production</string>
```

> **Important:** Do not use `$(APS_ENVIRONMENT)` — this build variable is only
> defined when archiving with a distribution profile and resolves to an empty
> string in all other build schemes, causing the entitlement to be silently
> ignored by iOS.

Use `production` for TestFlight and App Store builds.
Use `development` only if you are testing with a Development provisioning profile
(i.e. Xcode direct-install via the Run button).

### 1.3 Verify `project.pbxproj`

`CODE_SIGN_ENTITLEMENTS` must be set in **all three** build configurations
(Debug, Release, Profile). Search for the string in
`mobile/ios/Runner.xcodeproj/project.pbxproj`:

```
CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;
```

If it is missing or set to `""`, the entitlements file is not applied to the
binary. Fix by adding the line inside each build configuration block for the
`Runner` target, or by removing and re-adding the Push Notifications capability
in Xcode.

### 1.4 Verify SystemCapabilities in `project.pbxproj`

The Runner target's `PBXNativeTarget` section must include:

```
SystemCapabilities = {
    com.apple.Push = {
        enabled = 1;
    };
};
```

Without this, some Xcode versions will silently strip the push entitlement
during archiving.

---

## Part 2 — iOS Native Code (`AppDelegate.swift`)

The relevant methods look like this:

```swift
// Called when iOS successfully registers for remote notifications.
// Sends the APNs token to Flutter via MethodChannel('sync.notifications').
override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
) { … }

// Handles a push notification that arrives while the app is in the foreground.
// Remote APNs banners are suppressed here because the WebSocket already
// shows a local notification. Only local notifications (from WebSocket) are
// displayed.
func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
) {
    let isRemote = notification.request.trigger is UNPushNotificationTrigger
    completionHandler(isRemote ? [] : [.banner, .sound, .badge])
}

// Handles tap on a push notification that arrived while the app was
// closed or backgrounded.
func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
) {
    completionHandler()
}
```

---

## Part 3 — APNs Key (for Direct / Hybrid mode or Relay operator)

Skip this section if you are running in **relay mode** without hosting your own
relay.

### 3.1 Create an APNs Auth Key

1. Go to [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/authkeys/list).
2. Click **+** → select **Apple Push Notifications service (APNs)**.
3. Download the `.p8` file — **you can only download it once**.
4. Note the **Key ID** (10 chars) and your **Team ID** (shown top-right of the
   developer portal).

### 3.2 Convert the key for the server

The server accepts the raw `.p8` content as a single-line string with literal
`\n` escapes:

```bash
# Prints the key as a single line with \n escapes
awk 'NF {printf "%s\\n", $0}' AuthKey_XXXXXXXXXX.p8
```

Or base64-encode it:

```bash
base64 -w 0 AuthKey_XXXXXXXXXX.p8
```

Either format is accepted by the server.

### 3.3 Configure the server environment

Add to your server's `.env` (or Docker environment):

```dotenv
PUSH_DELIVERY_MODE=direct        # or hybrid
APNS_TEAM_ID=AB12CD34EF          # 10-char Team ID
APNS_KEY_ID=1A2B3C4D5E           # 10-char Key ID
APNS_BUNDLE_ID=com.icyanstudio.sync
APNS_PRIVATE_KEY_P8=-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----
APNS_USE_SANDBOX=false           # true only for dev/simulator builds
```

---

## Part 4 — Relay Mode (default)

No APNs credentials are needed on the server. Ensure:

```dotenv
PUSH_DELIVERY_MODE=relay
```

The server will forward push payloads to
`https://push.sync.icyanstudio.net/v1/push/webhook` by default. A custom relay
URL can be set from the admin dashboard → Config → Notification webhook URL.

Optionally set a shared secret to authenticate relay requests:

```dotenv
PUSH_RELAY_SHARED_SECRET=some-long-random-secret
```

The same secret must be configured on the relay server.

---

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| No push when app is closed | `aps-environment` missing or empty in entitlements; `CODE_SIGN_ENTITLEMENTS` not set in pbxproj |
| Push works in Xcode but not TestFlight | `aps-environment` set to `development` instead of `production` |
| Token is `null` on first launch | APNs registration is async; the app polls up to 6 × 1 s for the token |
| Duplicate notification when app is open | `willPresent` must suppress remote triggers — check `AppDelegate.swift` |
| Server logs "Push dispatch failed" for Linux tokens | Expected — Linux/Windows/macOS/web tokens are skipped from webhook relay (only `android`/`fcm` tokens are forwarded) |
| APNs returns 400 BadDeviceToken | Token is stale; client will re-register on next launch |
