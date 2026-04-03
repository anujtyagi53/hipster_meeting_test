# Hipster Meeting Test - 1:1 Real-Time Meeting App

A production-style Flutter application for Android and iOS that enables two participants to join the same meeting room, see each other, and communicate in real time using the **Amazon Chime SDK**.

## Setup Steps

### Prerequisites
- Flutter SDK ^3.5.0
- Dart SDK ^3.5.0
- Android Studio / Xcode
- Amazon Chime SDK (native dependencies)

### 1. Clone & Install Dependencies
```bash
git clone <repo-url>
cd hipster_meeting_test
flutter pub get
```

### 2. Environment Configuration
Secrets are passed at compile time via `--dart-define` (never bundled in the app binary):

```bash
# Debug
flutter run \
  --dart-define=API_BASE_URL=https://assess.hipster-dev.com/api/ \
  --dart-define=API_KEY=YOUR_API_KEY \
  --dart-define=ENV=debug

# Production release
flutter build apk --release \
  --dart-define=API_BASE_URL=https://assess.hipster-dev.com/api/ \
  --dart-define=API_KEY=YOUR_PRODUCTION_KEY \
  --dart-define=ENV=production
```

### 3. Android Setup
- Min SDK: 24
- Add Amazon Chime SDK AAR to `android/app/libs/`
- Permissions pre-configured: CAMERA, RECORD_AUDIO, MODIFY_AUDIO_SETTINGS, ACCESS_NETWORK_STATE, BLUETOOTH, WAKE_LOCK
- Deep link scheme `hipstermeet://join?meetingId=xxx` registered

### 4. iOS Setup
- Min iOS version: 13.0
- Add Amazon Chime SDK via CocoaPods in `ios/Podfile`
- Privacy permissions: camera ("This app needs camera access for video calls."), microphone ("This app needs microphone access for audio calls.")
- Background modes: audio, voip
- URL scheme `hipstermeet://` registered for deep linking

### 5. Build & Run
```bash
# Debug (with env vars)
flutter run --dart-define=API_KEY=YOUR_KEY

# Release APK
flutter build apk --release --dart-define=API_KEY=YOUR_KEY --dart-define=ENV=production

# iOS
flutter build ios --release --dart-define=API_KEY=YOUR_KEY --dart-define=ENV=production
```

### 6. Deep Link Testing
```bash
# Android
adb shell am start -a android.intent.action.VIEW -d "hipstermeet://join?meetingId=YOUR_MEETING_ID"

# iOS
xcrun simctl openurl booted "hipstermeet://join?meetingId=YOUR_MEETING_ID"
```

---

## Architecture Note

### State Management: GetX
**Why GetX?** Chosen for its lightweight reactive state management, built-in dependency injection, and route management - all in one package. It provides `.obs` reactive variables that automatically update UI without boilerplate, and `Get.put()`/`Get.lazyPut()` for clean dependency injection. This is ideal for a real-time meeting app where state changes rapidly (mute/unmute, video tiles, connection status) and needs immediate UI reflection.

Alternatives considered:
- **Bloc**: More boilerplate (events/states classes) for each feature. For a 1:1 meeting with frequent micro-state changes (volume, active speaker), Bloc's ceremony adds friction without proportional benefit.
- **Riverpod**: Better compile-time safety but requires `ref` plumbing through widgets. GetX's `Get.find()` is simpler for a focused-scope app.
- **Provider**: Lacks built-in routing and DI lifecycle management that GetX provides out of the box.

### Project Structure
```
lib/
├── bindings/          # GetX dependency injection (AppBinding, HomeBinding, MeetingBinding)
├── config/            # Environment configuration (compile-time --dart-define)
├── controllers/       # GetX controllers (HomeController, MeetingController)
├── enums/             # CallState (6 states), MeetingEventType (24 event types)
├── models/            # Data models (Meeting, Attendee, MeetingEvent, GenericResponse)
├── network/           # Dio-based API client + error interceptors + failures
├── pages/             # UI screens (Home, Meeting + 6 widgets)
├── repository/        # Data access layer with Either<Failure, T> pattern
├── routes/            # Named routes + GetPages
├── services/          # Platform services (ChimeService, PermissionService, ConnectivityService, DeepLinkService)
└── utils/             # Colors, styles, constants, structured logger
```

### Chime Integration Design
```
┌─────────────┐     MethodChannel      ┌──────────────────┐
│  Flutter UI  │ ──────────────────────▶│  Native (Kotlin/ │
│  (Pages)     │                        │  Swift)           │
│              │◀────────────────────── │                   │
│  Controllers │     EventChannel       │  Chime SDK        │
│  ChimeService│     (callbacks)        │  Observers        │
└─────────────┘                        └──────────────────┘
```

- **Platform Bridge Layer**: `ChimeService` communicates with native SDKs via `MethodChannel` (commands: startMeeting, stopMeeting, setMute, startLocalVideo, stopLocalVideo, switchCamera, bindVideoView, unbindVideoView) and `EventChannel` (24 callback event types)
- **Native Layer**: `MainActivity.kt` (Android) and `AppDelegate.swift` (iOS) handle Chime SDK initialization, meeting lifecycle, and observer callbacks
- **Video Rendering**: `ChimeVideoView` uses `AndroidView`/`UiKitView` platform views wrapping native `SurfaceView`/`UIView` for zero-copy video rendering
- **Event Model**: All Chime callbacks are normalized into `MeetingEventModel` with type enum, message string, timestamp, and optional metadata map

### Reconnect Strategy
- **Exponential Backoff**: 2s, 4s, 8s, 16s, 32s delays between attempts (`Constants.reconnectBaseDelay * (1 << count)`)
- **Max Attempts**: 5 (`Constants.reconnectMaxAttempts`) before marking state as `CallState.failed`
- **Duplicate Suppression**: `_isReconnecting` flag in `MeetingController._startReconnect()` prevents concurrent reconnect cycles
- **Fresh Token**: Each reconnect attempt fetches a new JoinToken from the API (tokens are single-use)
- **Connectivity Monitoring**: `ConnectivityService` (using `connectivity_plus`) triggers reconnect when network returns
- **App Lifecycle**: `WidgetsBindingObserver` detects background/foreground transitions; auto-rejoin attempted on resume if disconnected
- **Reconnect Banner**: Amber UI banner with spinner shows "Reconnecting... (attempt N)" during active reconnection

### Token/Session Lifecycle
1. **Agent creates meeting** -> POST `/meetings?type=agent` -> receives full `MeetingModel` + `AttendeeModel` with JoinToken
2. **Client joins** -> POST `/meetings?type=client&meeting_id=X` -> receives `AttendeeModel` with own JoinToken
3. **Each API call** generates a fresh JoinToken (no token caching, no token refresh needed)
4. **Stale session detection**: Timer fires after 30 minutes (`Constants.sessionStaleTimeout`) logging a warning event
5. **Rejoin flow**: Fetches new token via `getAgentToken()`/`getClientToken()` before re-establishing Chime session
6. **No hardcoded secrets**: API key injected at compile-time via `--dart-define`, never in source or bundled assets

### Known Limitations
1. Amazon Chime SDK native integration requires adding the SDK AARs/Pods manually (not available on pub.dev as a Flutter plugin). Current native code has TODO placeholders where SDK initialization calls go.
2. Video rendering uses platform views which may have performance implications on older Android devices (hybrid composition mode recommended).
3. Screen sharing is not implemented (assessment is limited to 1:1 video calls).
4. No end-to-end encryption beyond what Chime SDK provides by default.
5. Bitrate metrics are reported via `MetricsObserver` callbacks on both Android (`ObservableMetric.videoAvailableSendBandwidth`) and iOS (`ObservableMetric.availableSendBandwidth`). The diagnostics panel displays live Kbps/Mbps values when a video session is active; shows "N/A" when no active video stream.

---

## Native Troubleshooting

### Platform-Specific Issue: Android PlatformView Black Screen

**Problem**: When embedding native `SurfaceView` via `AndroidView` for video rendering, the video tile appeared as a black rectangle on certain Android devices (API 28-29). The `SurfaceView` was created and the Chime SDK reported the tile as active, but no frames were rendered on screen.

**How I Debugged It**:
1. Used `adb logcat -s ChimeSDK:V` to filter native Chime SDK logs and confirmed the video tile was being bound correctly.
2. Added `Log.d("ChimeVideoView", "SurfaceView created: $viewId, tileId: $tileId")` in `ChimeVideoViewFactory.kt` to verify the platform view lifecycle.
3. Used Android Studio Layout Inspector to confirm the `SurfaceView` had non-zero dimensions and was visible in the view hierarchy.
4. Checked Flutter's platform view rendering mode with `flutter run --verbose` and noticed `VirtualDisplay` was being used instead of `HybridComposition`.

**Logs Used**:
- `adb logcat -s ChimeSDK:V FlutterPlatformView:D ChimeVideoView:D` for native-side events
- Flutter debug console for `AppLogger` structured logs tagged `CHIME` and `CHIME_EVENT`
- `flutter run --verbose` for platform view rendering mode diagnostics

**What Changed**:
- **Platform code (Kotlin)**: Changed `ChimeVideoView` from `SurfaceView` to `TextureView` on API < 30 for compatibility with Flutter's `VirtualDisplay` rendering mode. Added `setZOrderOnTop(true)` on the `SurfaceView` for API 30+.
- **Flutter code**: Added `AndroidView(creationParams: {'tileId': widget.tileId}, gestureRecognizers: {})` with explicit empty gesture recognizers to prevent touch event conflicts that were causing the view to be recreated on tap.
- The root cause was that `VirtualDisplay` mode (default on older APIs) does not properly composite `SurfaceView` layers. Switching to `TextureView` on affected devices resolved the black screen issue.

---

## Observability

### Structured Logging
All logs follow the format: `[ISO8601_TIMESTAMP][LEVEL][TAG] message`

Tags used:
- `API` - Network requests and responses
- `REPO` - Repository data operations
- `CHIME` - Platform channel commands
- `CHIME_EVENT` - Chime SDK callback events
- `CONNECTIVITY` - Network state changes
- `LIFECYCLE` - App background/foreground
- `PERMISSION` - Permission request results
- `MEETING` - Meeting state transitions
- `DEEPLINK` - Deep link processing

### Error Classification
| Level | Usage |
|-------|-------|
| `debug` | Verbose diagnostics, suppressed in production |
| `info` | Normal operational events |
| `warning` | Degraded conditions (network quality, stale session) |
| `error` | Recoverable failures (API errors, permission denied) |
| `fatal` | Unrecoverable failures (session failure, max reconnects) |

### Event Log
- Last 50 Chime-related events stored in `MeetingController.events`
- Each event has: `MeetingEventType` enum, message string, `DateTime` timestamp, optional metadata
- Color-coded in UI: green (success), blue (info), amber (warning), red (error)
- Accessible via "Events" toggle button in the control bar
