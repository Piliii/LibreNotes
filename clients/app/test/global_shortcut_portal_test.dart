import 'package:flutter_test/flutter_test.dart';
import 'package:librenotes/desktop/global_shortcut_portal.dart';

void main() {
  test('request path follows the portal spec', () {
    expect(GlobalShortcutPortal.requestPath(':1.234', 'tok'),
        '/org/freedesktop/portal/desktop/request/1_234/tok');
  });
}
