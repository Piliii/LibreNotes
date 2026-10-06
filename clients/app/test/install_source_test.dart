import 'package:flutter_test/flutter_test.dart';
import 'package:librenotes/android/install_source.dart';

void main() {
  test('classifyInstaller maps known installers, never throws', () {
    expect(classifyInstaller('org.fdroid.fdroid'), InstallSource.fdroid);
    expect(classifyInstaller('com.android.vending'), InstallSource.play);
    expect(classifyInstaller('com.google.android.packageinstaller'),
        InstallSource.other);
    expect(classifyInstaller(null), InstallSource.unknown);
    expect(classifyInstaller(''), InstallSource.unknown);
  });

  test('signingSplitNote: F-Droid and sideload warn, Play does not', () {
    expect(signingSplitNote(InstallSource.fdroid), contains('F-Droid'));
    expect(signingSplitNote(InstallSource.fdroid), contains('GitHub'));
    expect(signingSplitNote(InstallSource.other), contains('uninstall'));
    expect(signingSplitNote(InstallSource.unknown), isNotNull);
    expect(signingSplitNote(InstallSource.play), isNull);
  });
}
