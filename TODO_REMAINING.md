# Assessment - Remaining Items

## Must Do (Before Submission)

- [x] **Build Release APK** - Done! `app-release.apk` (96MB) in project root
- [ ] **Build iOS IPA / Xcode project** - Add release signing config in build.gradle.kts & Xcode signing team
- [ ] **Record Demo Video (5-8 min)** - Must demonstrate the failure matrix:
  1. User B joins 20 seconds late
  2. User A turns off camera, then back on
  3. User A loses network for 10 seconds
  4. User A backgrounds the app, returns after 15 seconds
  5. User B leaves, then rejoins the same meeting
  6. Mic permission denied first, then granted later
- [ ] **Show native troubleshooting in video** - Explain one platform-specific bug, how you debugged it, what logs you used

## Nice to Have

- [ ] **Unit/widget tests** - /test directory is empty
- [ ] **Add release signing config** - Android: keystore setup in build.gradle.kts (currently has TODO at L35)

## Already Done (verified)

- [x] **Live bitrate metrics** - MetricsObserver implemented on both Android (MainActivity.kt L396-408) and iOS (AppDelegate.swift L372-383). Shows Kbps/Mbps when video active.
