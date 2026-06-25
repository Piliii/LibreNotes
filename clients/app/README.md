# LibreNotes — client

Flutter client for LibreNotes. Runs on Android, Linux desktop, and web from a
single codebase.

## Requirements

- Flutter SDK (dart included): `export PATH="$PATH:/path/to/flutter/bin"`
- A running LibreNotes sync server (see [server README](../../server/README.md))

## Development

```bash
flutter pub get

flutter run -d linux          # Linux desktop
flutter run -d chrome         # web
flutter run                   # Android (device or emulator)

flutter test                  # run all tests (unit + sync e2e)
flutter analyze               # static analysis
```

## Release builds

### Android (arm64)

```bash
flutter build apk --release --target-platform android-arm64
```

The APK is at `build/app/outputs/flutter-apk/app-release.apk`.

> **Note:** The `applicationId` is `dev.librenotes.app`. If you previously had
> an older build installed, uninstall it first before installing the release APK.

### Linux

```bash
flutter build linux --release
```

Bundle is at `build/linux/x64/release/bundle/`.

## F-Droid

All dependencies are FOSS. There are no Google Play Services, Firebase, or
proprietary SDK references. The `INTERNET` permission is declared in the main
manifest so sync works in release builds.

Fastlane metadata lives in `fastlane/metadata/android/en-US/`.

## Sync & encryption

The client talks to the sync server over HTTP with a bearer token. All
encryption (XChaCha20-Poly1305 + Argon2id) is done locally in
`lib/sync/note_crypto.dart`. The server never receives plaintext or keys.

Enter the server URL and passphrase in **Settings → Sync**.
