# PCU Connect on Android and iPhone

The web app at https://pcu-workflow.web.app is the live app. This page lists what the Android and iPhone apps already
have, and exactly what a real release still needs from the owner.

## What is already done (branch phase-1-firestore)
- `android/` and `ios/` projects exist. App name **PCU Connect** on both.
- App id: Android `com.pcu.workflow`, iOS bundle id `com.pcu.workflow`.
- Launcher icons from the PCU logo (flutter_launcher_icons): Android adaptive icon (gold mark on navy #0B1F3A, plus a
  monochrome layer for Android 13 themed icons) and every iOS AppIcon size.
- Android push notification icon: the white PCU badge (`@drawable/ic_notification`), tinted navy.
- Android release builds have the INTERNET permission.
- Firebase is set up for Android in the app (`lib/firebase_options.dart`, from `android/app/google-services.json`).
  iOS is not registered yet, so an iPhone build stops at start until the steps below are done.
- Google sign-in uses the system sign-in on Android and iOS (`signInWithProvider`) and a pop-up on the web.
- GitHub Actions:
  - `.github/workflows/android.yml` builds a **debug APK** (Firestore mode) and attaches it to the run as the artifact
    `pcu-connect-debug-apk`. Run it from the Actions tab ("Run workflow") or by pushing app changes to this branch.
  - `.github/workflows/ios.yml` checks that the iOS app **compiles** (`flutter build ios --no-codesign`). It does not
    make an installable app.

## Android: what a real release needs from you
1. **SHA-1 and SHA-256 fingerprints in Firebase** (needed for Google sign-in on Android; without them sign-in fails).
   - Debug key (for the CI debug APK): the fingerprints of the key that signs it. On any machine with the Android SDK:
     `keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android`
     (CI uses a fresh debug key per run; for testing on a phone it is easier to use one fixed debug key, see 2.)
   - Release (upload) key: the fingerprints of the key from step 2.
   - Google Play app signing key: after the first upload, Play Console, Test and release, App integrity, copy its SHA-1
     and SHA-256.
   - Add all of them in Firebase console, Project settings, Your apps, the Android app `com.pcu.workflow`, Add
     fingerprint. Then download the new `google-services.json` and replace `android/app/google-services.json`
     (it then lists OAuth clients; today it has none).
2. **A signing key** for release builds:
   `keytool -genkey -v -keystore pcu-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias pcu`
   Keep the file and its passwords safe and private (never in the repo). Send it to whoever builds releases through a
   secure channel, or add it to GitHub as encrypted secrets; then `android/app/build.gradle.kts` gets a release
   `signingConfig` that reads `android/key.properties` (not committed).
3. **Google Play Console** account (one-time fee), a store listing (name, short description, screenshots, the PCU icon),
   a privacy policy URL, and the data safety form (the app stores names, phone numbers and follow-up notes).
4. Build for Play: `flutter build appbundle --release --dart-define=DATA_SOURCE=firestore --dart-define=APPS_SCRIPT_URL=<exec url>`.

## iPhone: what a real release needs from you
1. **Apple Developer Program membership** (paid, yearly). Without it an iPhone can only run the app for a few days from
   a developer's own Mac, and push notifications do not work at all.
2. **A Mac with Xcode** (or a CI service with your signing certificates) to sign and upload the app.
3. **Register the iOS app in Firebase**: Firebase console, Project settings, Add app, iOS, bundle id
   `com.pcu.workflow`. Download `GoogleService-Info.plist` into `ios/Runner/` and run `flutterfire configure` so
   `lib/firebase_options.dart` gets the iOS options.
4. **Google sign-in on iPhone**: add the `REVERSED_CLIENT_ID` from `GoogleService-Info.plist` as a URL scheme in
   `ios/Runner/Info.plist` (Xcode, Runner, Info, URL Types).
5. **Push notifications**: in the Apple Developer site create an APNs key (.p8), and upload it in Firebase console,
   Project settings, Cloud Messaging, Apple app configuration. In Xcode turn on the capabilities Push Notifications and
   Background Modes, Remote notifications, and pick your team for signing.
6. **App Store Connect**: create the app, TestFlight for testers, then App Review. Same privacy and data questions as
   Google Play.

## How push notifications differ on native
- **Web (today):** browser push through a service worker and a VAPID key; tokens are saved at
  `users/{email}/tokens/{token}` with `platform: 'web'`; no custom sound when the app is closed.
- **Android and iOS:** the token comes straight from FCM (no VAPID key, no service worker). Android 13 and later asks
  the person for notification permission (the app's "Turn on" card already asks at the right time). iOS needs the APNs
  key above. Native apps can play the PCU chime even when closed (Android `res/raw`, iOS app bundle).
- **Code still to do for native push** (small, once the platform setup above exists): enable `PushService` off the web,
  save tokens with `platform: 'android'` or `'ios'`, allow those two values in `firestore.rules` (today only `'web'` is
  accepted), and show foreground notifications with a local notification. The Apps Script sender already uses the FCM
  HTTP v1 API, which works for all three platforms; it only needs the `android` and `apns` blocks for the sound and icon.
- **Same blocker as the web:** the service account needs the role "Firebase Cloud Messaging API Admin" before any push
  can be sent.

## Summary of what only the owner can provide
| Item | For | Where |
|---|---|---|
| SHA-1 and SHA-256 fingerprints, new google-services.json | Android sign-in | Firebase console |
| Upload signing key (kept private) | Android release | `keytool`, then secrets |
| Google Play Console account | Android release | play.google.com/console |
| Apple Developer Program membership | Any iPhone install, iPhone push | developer.apple.com |
| iOS app in Firebase, GoogleService-Info.plist | iPhone sign-in and data | Firebase console |
| APNs key uploaded to Firebase | iPhone push | Apple Developer, Firebase console |
| Firebase Cloud Messaging API Admin role for the service account | Any push (web and native) | Google Cloud IAM |
