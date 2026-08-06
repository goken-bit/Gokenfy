#!/usr/bin/env python3
"""Patch the flutter create-generated AndroidManifest.xml so just_audio_background works.

just_audio_background (audio_service) requires:
- WAKE_LOCK, FOREGROUND_SERVICE, FOREGROUND_SERVICE_MEDIA_PLAYBACK permissions
- MainActivity to be com.ryanheise.audioservice.AudioServiceActivity
- The AudioService <service> and MediaButtonReceiver <receiver>

The CI regenerates android/ from scratch each build, so we apply these after
`flutter create`.
"""
import sys
import re

MANIFEST = "android/app/src/main/AndroidManifest.xml"

PERMISSIONS = """    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
"""

SERVICE = """    <service android:name="com.ryanheise.audioservice.AudioService"
        android:foregroundServiceType="mediaPlayback"
        android:exported="true" tools:ignore="Instantiatable">
      <intent-filter>
        <action android:name="android.media.browse.MediaBrowserService" />
      </intent-filter>
    </service>
    <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
        android:exported="true" tools:ignore="Instantiatable">
      <intent-filter>
        <action android:name="android.intent.action.MEDIA_BUTTON" />
      </intent-filter>
    </receiver>
"""


def patch() -> None:
    with open(MANIFEST, "r", encoding="utf-8") as f:
        xml = f.read()

    changed = False

    # Rename the app (flutter create labels it with the project name).
    if 'android:label="Zen"' not in xml:
        xml = re.sub(
            r'android:label="[^"]*"',
            'android:label="Zen"',
            xml,
            count=1,
        )
        changed = True

    # The in-app stream proxy serves audio over http://127.0.0.1, which Android
    # blocks by default on API 28+. Allow cleartext to the loopback interface.
    if "usesCleartextTraffic" not in xml:
        xml = xml.replace(
            "<application",
            '<application android:usesCleartextTraffic="true"',
            1,
        )
        changed = True

    if "android.permission.INTERNET" not in xml:
        xml = re.sub(
            r"(<manifest[^>]*>)",
            r"\1\n" + PERMISSIONS.rstrip("\n"),
            xml,
            count=1,
        )
        changed = True

    if "AudioServiceActivity" not in xml:
        xml = xml.replace(
            'android:name=".MainActivity"',
            'android:name="com.ryanheise.audioservice.AudioServiceActivity"',
        )
        changed = True

    if "android.media.browse.MediaBrowserService" not in xml:
        xml = re.sub(
            r"(</application>)",
            SERVICE + r"\1",
            xml,
            count=1,
        )
        changed = True

    if "tools:" in xml and "xmlns:tools" not in xml:
        xml = re.sub(
            r'(<manifest[^>]*?)>',
            r'\1 xmlns:tools="http://schemas.android.com/tools">',
            xml,
            count=1,
        )
        changed = True

    with open(MANIFEST, "w", encoding="utf-8") as f:
        f.write(xml)

    if changed:
        print("AndroidManifest.xml patched for audio_service")
    else:
        print("AndroidManifest.xml already patched")


if __name__ == "__main__":
    if len(sys.argv) > 1:
        MANIFEST = sys.argv[1]
    patch()
