import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:librenotes/sync/sync_api.dart';

/// A client whose requests never complete, like a connect to a host that
/// silently drops packets (internet up, LAN-only server unreachable).
class _HangingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      Completer<http.StreamedResponse>().future;
}

void main() {
  test('requests to an unresponsive server time out instead of hanging', () {
    final api = SyncApi(
      baseUrl: 'http://10.255.255.1:8080',
      token: 'tok',
      client: _HangingClient(),
      timeout: const Duration(milliseconds: 50),
    );
    expect(api.changes(0), throwsA(isA<TimeoutException>()));
    expect(api.getKeystore(), throwsA(isA<TimeoutException>()));
    expect(api.checkApiVersion(), throwsA(isA<TimeoutException>()));
  });
}
