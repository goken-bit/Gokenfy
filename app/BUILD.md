# Building Gokenfy APK on a PC

The project source lives here in `app/`. Build the APK on any desktop (Linux/macOS/Windows)
with Flutter installed. This folder intentionally has **no** `android/` scaffolding yet —
you generate it once with `flutter create`, which guarantees it matches your Flutter version.

## 1. Install prerequisites (once)
- [Flutter SDK](https://docs.flutter.dev/get-started/install) — stable channel (`flutter --version` ≥ 3.27)
- Android Studio (or the Android SDK command-line tools) + a JDK 17
- Run `flutter doctor` until "Android toolchain" is green

## 2. Generate the platform project
```bash
cd <this folder>/app
flutter create --org com.gokenfy --project-name gokenfy .
flutter pub get
```

This creates `android/`, `ios/`, etc. It will **not** overwrite `lib/`, `pubspec.yaml`,
or your other files.

## 3. Verify code
```bash
flutter analyze
```
Should report zero errors (some "info" is fine).

## 4. App identity
- **App name:** `android/app/src/main/AndroidManifest.xml` → set `android:label="Gokenfy"`
- **Icon:** replace `android/app/src/main/res/mipmap-*/ic_launcher.png` (recommend
  `flutter_launcher_icons` — add to `dev_dependencies`, run `dart run flutter_launcher_icons`)
- **Permissions:** the default manifest already includes `android.permission.INTERNET`,
  which is all the base app needs.

## 5. Build the APK
```bash
flutter build apk --release --split-per-abi
```

## 5b. Background playback + media notification
Playback in the background and the lock-screen/notification controls rely on
`just_audio_background`. Add the following to
`android/app/src/main/AndroidManifest.xml` inside `<manifest>`, **before**
`<application>`:

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

Inside `<application>`, add:

```xml
<service
    android:name="com.ryanheise.audioservice.AudioService"
    android:foregroundServiceType="mediaPlayback"
    android:exported="true">
    <intent-filter>
        <action android:name="android.media.browse.MediaBrowserService" />
    </intent-filter>
</service>
<service
    android:name="com.ryanheise.audioservice.AudioServiceNotification"
    android:exported="false"
    android:foregroundServiceType="mediaPlayback" />
<receiver
    android:name="com.ryanheise.audioservice.MediaButtonReceiver"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.MEDIA_BUTTON" />
    </intent-filter>
</receiver>
```

> The service class names above come from `audio_service`, which
> `just_audio_background` depends on. If a newer audio_service version uses a
> different shadowed service name, check `audio_service`'s README and adjust.

Outputs:
```
build/app/outputs/flutter-apk/app-release-arm64-v8a.apk   (most phones)
build/app/outputs/flutter-apk/app-release-armeabi-v7a.apk
build/app/outputs/flutter-apk/app-release-x86_64.apk
```

Install on your phone (USB debugging on):
```bash
adb install build/app/outputs/flutter-apk/app-release-arm64-v8a.apk
```
Or copy the `.apk` to the phone and tap it (allow "install unknown apps").

## 6. Signing (optional, for wider distribution)
Debug builds are auto-signed. For a personal release APK:
```bash
keytool -genkey -v -keystore ~/gokenfy-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias gokenfy
```
Then point `android/app/build.gradle.kts` `signingConfigs` at it, or use
`flutter build apk --release` with the default debug signing for personal use.

## 7. Troubleshooting
- `Could not find ... local.properties` → run `flutter pub get` / `flutter create .` again.
- Android Gradle needs network access on first build (downloads dependencies).
- If `just_audio`/`audio_service` errors: make sure you ran `flutter create .` so the
  generated Gradle files match your Flutter version, then `flutter clean && flutter pub get`.
