#!/usr/bin/env python3
"""Patch the generated android/ project to sign release APKs with a stable
committed keystore (gokenfy.p12).

Flutter's default template signs release builds with the debug keystore,
which GitHub Actions regenerates with a fresh random key on every run. That
makes each build's APK signature differ, so `pm install -r` (updates) fail
with INSTALL_FAILED_UPDATE_INCOMPATIBLE. This script wires up a fixed
signing config so every build shares the same signature.
"""
import os
import re
import shutil
import sys

APP_DIR = "android/app"
GRADLE = os.path.join(APP_DIR, "build.gradle.kts")
KEYSTORE_SRC = "../.github/keystore/gokenfy.p12"
KEYSTORE_DST = os.path.join(APP_DIR, "keystore", "gokenfy.p12")
KEY_PROPERTIES = "android/key.properties"

# Keep in sync with how the keystore was generated (.github/keystore/README.md).
PASSWORD = "gokenfy"
KEY_ALIAS = "gokenfy"

GRADLE_SIGNING = """
    signingConfigs {
        create("release") {
            keyAlias = "gokenfy"
            keyPassword = "gokenfy"
            storeFile = file("keystore/gokenfy.p12")
            storePassword = "gokenfy"
        }
    }
"""


def patch() -> None:
    changed = False

    # 1) Drop the keystore into the app module.
    if not os.path.exists(KEYSTORE_SRC):
        print(f"keystore not found: {KEYSTORE_SRC}")
        sys.exit(1)
    os.makedirs(os.path.dirname(KEYSTORE_DST), exist_ok=True)
    shutil.copy2(KEYSTORE_SRC, KEYSTORE_DST)
    print("keystore copied to android/app/keystore/gokenfy.p12")

    # 2) Point the release build type at the stable signing config.
    with open(GRADLE, "r", encoding="utf-8") as f:
        gradle = f.read()

    if 'create("release")' not in gradle:
        # Insert the signingConfigs block right before `buildTypes {`.
        gradle = gradle.replace(
            "    buildTypes {",
            GRADLE_SIGNING + "\n    buildTypes {",
            1,
        )
        changed = True

    if 'signingConfigs.getByName("release")' not in gradle:
        gradle = re.sub(
            r"signingConfig\s*=\s*signingConfigs\.getByName\(\"debug\"\)",
            'signingConfig = signingConfigs.getByName("release")',
            gradle,
        )
        changed = True

    with open(GRADLE, "w", encoding="utf-8") as f:
        f.write(gradle)

    # 3) Write key.properties (mirrors the hardcoded values above).
    with open(KEY_PROPERTIES, "w", encoding="utf-8") as f:
        f.write(
            "storePassword=gokenfy\n"
            "keyPassword=gokenfy\n"
            "keyAlias=gokenfy\n"
            "storeFile=app/keystore/gokenfy.p12\n"
        )

    print("build.gradle.kts patched for stable release signing")


if __name__ == "__main__":
    if len(sys.argv) > 1:
        # Allow overriding the working dir (defaults to repo root).
        os.chdir(sys.argv[1])
    patch()
