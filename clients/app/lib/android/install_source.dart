import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Where the running APK was installed from, via the native
/// `getInstallerPackageName` (MainActivity.kt). Local only, no network.
enum InstallSource { fdroid, play, other, unknown }

const _channel = MethodChannel('dev.librenotes.app/install');

/// Maps an installer package name to a source. Null/unrecognised (sideloaded
/// APK, `adb install`, platform without the API) is [InstallSource.unknown]
/// or [InstallSource.other] — never throws.
InstallSource classifyInstaller(String? pkg) {
  switch (pkg) {
    case null:
    case '':
      return InstallSource.unknown;
    case 'org.fdroid.fdroid':
    case 'org.fdroid.basic':
    case 'org.fdroid.fdroid.privileged':
      return InstallSource.fdroid;
    case 'com.android.vending':
      return InstallSource.play;
    default:
      return InstallSource.other;
  }
}

/// The signing-split warning for [source], or null when there's nothing
/// useful to say (e.g. Play, which manages its own signing).
String? signingSplitNote(InstallSource source) {
  switch (source) {
    case InstallSource.fdroid:
      return 'Installed from F-Droid. Updates from GitHub Release APKs '
          'won’t install over this copy (different signing keys) — keep '
          'updating through F-Droid.';
    case InstallSource.other:
    case InstallSource.unknown:
      return 'Installed outside F-Droid. If you later switch to the F-Droid '
          'build (or the reverse), the update won’t install over this copy '
          'because the signing keys differ — you’d need to uninstall first. '
          'Pick one source and stay with it.';
    case InstallSource.play:
      return null;
  }
}

/// Null off Android, where there's no install source to report.
Future<InstallSource?> detectInstallSource() async {
  if (kIsWeb || !Platform.isAndroid) return null;
  try {
    return classifyInstaller(
        await _channel.invokeMethod<String>('getInstallerPackageName'));
  } catch (_) {
    return InstallSource.unknown;
  }
}
