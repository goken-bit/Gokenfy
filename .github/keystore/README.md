# Release signing keystore

`gokenfy.p12` is a PKCS#12 keystore committed so every CI build signs APKs
with the same key. Without it, GitHub Actions generates a fresh random debug
keystore per run, making each APK signature different and forcing a
full uninstall/reinstall instead of `pm install -r`.

How it was generated (OpenSSL, once):

```
openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem \
  -days 10000 -nodes -subj '/CN=Gokenfy'
openssl pkcs12 -export -out gokenfy.p12 \
  -inkey key.pem -in cert.pem -name gokenfy -passout pass:gokenfy
```

- store password: gokenfy
- key password: gokenfy
- key alias: gokenfy
- validity: 10000 days (re-generate before expiry and bump the app version)

`patch_signing.py` copies this keystore into the fresh `flutter create`
project and rewrites `build.gradle.kts` to use it for release signing.
