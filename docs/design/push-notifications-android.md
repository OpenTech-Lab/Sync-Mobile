# Android Push Notifications Setup (FCM)

Android push notifications when the app is closed or backgrounded require
**Firebase Cloud Messaging (FCM)**. Unlike iOS (where the system handles
delivery via APNs), Android has no built-in push mechanism for third-party apps
other than FCM.

This document covers everything needed to wire up FCM end-to-end: the Firebase
project, the Android app changes, and the server-side relay configuration.

---

## Overview of what needs to change

| Layer | Change |
|---|---|
| Firebase console | Create project, enable FCM, download config |
| `android/app/build.gradle.kts` | Apply `google-services` plugin, add Firebase SDK |
| `android/build.gradle.kts` | Add `google-services` classpath |
| `android/app/src/main/AndroidManifest.xml` | Register background message service |
| New: `SyncFirebaseMessagingService.kt` | Handle push when app is killed |
| `MainActivity.kt` | Return real FCM token from `getPushToken` |
| Relay server | Forward `fcm`/`android` tokens to FCM HTTP v1 API |

---

## Part 1 — Firebase Project Setup

### 1.1 Create a Firebase project

1. Go to <https://console.firebase.google.com> and click **Add project**.
2. Name it (e.g. `sync-push`) and complete the wizard. Google Analytics is not
   required.

### 1.2 Add an Android app to the project

1. In the project overview click the **Android** icon (**+** → Android).
2. Enter the package name exactly: `com.icyanstudio.sync`
   (or your forked bundle ID matching `namespace` in `android/app/build.gradle.kts`).
3. Nickname and SHA-1 are optional for push; skip them.
4. Download **`google-services.json`** and place it at:

   ```
   mobile/android/app/google-services.json
   ```

5. Skip the "Add Firebase SDK" wizard steps — the Gradle changes are listed
   below.

### 1.3 Confirm FCM is enabled

In the Firebase console go to **Project Settings → Cloud Messaging**. The
Firebase Cloud Messaging API should show as enabled. If it shows a "Firebase
Cloud Messaging API (V1)" toggle, enable it — the legacy API was deprecated.

---

## Part 2 — Android Build Files

### 2.1 `android/build.gradle.kts`

Add the `google-services` plugin to the project-level build file:

```kotlin
// At the top of the file, add:
plugins {
    id("com.google.gms.google-services") version "4.4.2" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
// … rest unchanged …
```

### 2.2 `android/app/build.gradle.kts`

Apply the plugin and add the Firebase BoM + Messaging dependency:

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")   // ← add this
}

// … android { } block unchanged …

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.9.0"))
    implementation("com.google.firebase:firebase-messaging-ktx")
}

flutter {
    source = "../.."
}
```

---

## Part 3 — Background Message Handler (`SyncFirebaseMessagingService.kt`)

Create a new file at the same package path as `MainActivity.kt`:

```
mobile/android/app/src/main/kotlin/com/icyanstudio/sync/SyncFirebaseMessagingService.kt
```

```kotlin
package com.icyanstudio.sync

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class SyncFirebaseMessagingService : FirebaseMessagingService() {

    private val notificationChannelId = "sync_messages"

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)
        // Show the notification when the app is in the background/killed.
        // When the app is in the foreground the WebSocket already shows a
        // local notification; FCM delivery is suppressed there by not
        // including a `notification` block in the payload (data-only message).
        val title = message.data["title"] ?: message.notification?.title ?: "Sync"
        val body  = message.data["body"]  ?: message.notification?.body  ?: "New message"

        createNotificationChannelIfNeeded()

        val builder = NotificationCompat.Builder(this, notificationChannelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)

        NotificationManagerCompat.from(this)
            .notify((System.currentTimeMillis() % Int.MAX_VALUE).toInt(), builder.build())
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        // Token rotation is handled by the app when it next opens.
        // For immediate re-registration you could broadcast an Intent here.
    }

    private fun createNotificationChannelIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(notificationChannelId) != null) return
        manager.createNotificationChannel(
            NotificationChannel(notificationChannelId, "Messages", NotificationManager.IMPORTANCE_HIGH)
        )
    }
}
```

---

## Part 4 — `AndroidManifest.xml`

Register the service inside the `<application>` tag:

```xml
<service
    android:name=".SyncFirebaseMessagingService"
    android:exported="false">
    <intent-filter>
        <action android:name="com.google.firebase.MESSAGING_EVENT" />
    </intent-filter>
</service>
```

---

## Part 5 — `MainActivity.kt` — Return the Real FCM Token

Replace the stub `getPushToken` handler with one that fetches the FCM
registration token:

### Imports to add

```kotlin
import com.google.firebase.messaging.FirebaseMessaging
```

### Replace the `getPushToken` branch

Current stub:
```kotlin
"getPushToken" -> result.success(null)
```

Replace with:
```kotlin
"getPushToken" -> {
    FirebaseMessaging.getInstance().token
        .addOnSuccessListener { token -> result.success(token) }
        .addOnFailureListener { result.success(null) }
}
```

---

## Part 6 — Dart / `notification_service.dart`

The Dart layer already calls `getPushToken` via `MethodChannel('sync.notifications')`
and sends the token to the server with a `platform` field. Verify that
`_platformName()` returns `"android"` (or `"fcm"`) for Android — the server's
relay filter accepts both:

```dart
// In notification_service.dart
String _platformName() {
  if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
  if (defaultTargetPlatform == TargetPlatform.android) return 'android';
  // …
}
```

No changes needed here unless `_platformName()` currently returns something
other than `android` / `fcm`.

---

## Part 7 — Server / Relay Configuration

### 7.1 How the relay delivers to Android

The relay at `push.sync.icyanstudio.net` receives the push payload from your
server and must forward it to the **FCM HTTP v1 API** using a Firebase service
account.

The relay needs to be given your Firebase project's service account credentials.
Contact the relay operator (or configure your own relay) with:

- **Firebase project ID** — visible in Project Settings → General
- **Service account JSON** — Project Settings → Service accounts →
  **Generate new private key**

> If you are running your own relay, store the JSON path in the relay's
> environment and use the
> [FCM HTTP v1 API](https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages/send)
> to send messages. Authenticate with an OAuth 2.0 token obtained from the
> service account JSON using the `https://www.googleapis.com/auth/firebase.messaging` scope.

### 7.2 FCM payload for background notifications

Send a **data-only** message (no `notification` key) so FCM delivers it to
`onMessageReceived` even when the app is in the foreground. The
`SyncFirebaseMessagingService` will then show the notification manually only
when the app is backgrounded/killed (you can add an `isBackground` flag in the
payload or check `ProcessLifecycleOwner` if needed):

```json
{
  "message": {
    "token": "<FCM_DEVICE_TOKEN>",
    "data": {
      "title": "Sync",
      "body": "a new message"
    },
    "android": {
      "priority": "high"
    }
  }
}
```

---

## Part 8 — Testing

1. Build and install a debug APK with `flutter run`.
2. Open the app once so the FCM token is registered with the server.
3. Check the server DB to confirm a token with `platform = 'android'` is stored
   for your user.
4. Kill the app on the device.
5. Send yourself a message from another account; the push notification should
   appear.

To inspect the FCM token manually:

```bash
# In a chat:
adb logcat | grep -i fcm
# Or add a debug log in onNewToken / getPushToken handler
```

---

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `google-services.json` not found at build time | File must be at `android/app/google-services.json`, not project root |
| FCM token is `null` | Google Play Services not available (emulator without Play Store); use a real device |
| Notification shown when app is open | Use a data-only FCM message (no `notification` key); handle foreground display in `onMessageReceived` only when needed |
| Token registered but no push received | Relay not configured with Firebase service account credentials for your project |
| Build fails: "Plugin with id 'com.google.gms.google-services' not found" | `google-services` classpath in `android/build.gradle.kts` missing or wrong version |
| `POST_NOTIFICATIONS` permission denied on Android 13+ | Already handled in `MainActivity.kt` via `requestPushPermission` — ensure user grants it |
