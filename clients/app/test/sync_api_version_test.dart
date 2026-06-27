import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:librenotes/sync/sync_api.dart';

/// Unit tests for the client-side version-mismatch detection logic.
/// Each test spins up a tiny shelf server that returns a controlled
/// X-Librenotes-Api-Version header, then drives SyncApi against it.
void main() {
  Future<(HttpServer, String)> startServer(Handler handler) async {
    final server = await shelf_io.serve(handler, 'localhost', 0);
    return (server, 'http://localhost:${server.port}');
  }

  group('checkApiVersion', () {
    test('no exception when server returns version 1', () async {
      final (srv, url) = await startServer((_) => Response.ok(
            '{"ok":true}',
            headers: {
              'content-type': 'application/json',
              'x-librenotes-api-version': '1',
            },
          ));
      final api = SyncApi(baseUrl: url, token: 'tok');
      addTearDown(() async {
        api.close();
        await srv.close(force: true);
      });

      await expectLater(api.checkApiVersion(), completes);
    });

    test('no exception when server sends no version header (old server)',
        () async {
      final (srv, url) = await startServer((_) => Response.ok(
            '{"ok":true}',
            headers: {'content-type': 'application/json'},
          ));
      final api = SyncApi(baseUrl: url, token: 'tok');
      addTearDown(() async {
        api.close();
        await srv.close(force: true);
      });

      await expectLater(api.checkApiVersion(), completes);
    });

    test('VersionMismatchException when server version is greater than 1',
        () async {
      final (srv, url) = await startServer((_) => Response.ok(
            '{"ok":true}',
            headers: {
              'content-type': 'application/json',
              'x-librenotes-api-version': '2',
            },
          ));
      final api = SyncApi(baseUrl: url, token: 'tok');
      addTearDown(() async {
        api.close();
        await srv.close(force: true);
      });

      await expectLater(
        api.checkApiVersion(),
        throwsA(isA<VersionMismatchException>()
            .having((e) => e.serverVersion, 'serverVersion', 2)
            .having((e) => e.clientVersion, 'clientVersion', 1)),
      );
    });
  });

  group('changes version check', () {
    test('no exception when changes response carries version 1', () async {
      final (srv, url) = await startServer((_) => Response.ok(
            '{"notes":[],"latestSeq":0}',
            headers: {
              'content-type': 'application/json',
              'x-librenotes-api-version': '1',
            },
          ));
      final api = SyncApi(baseUrl: url, token: 'tok');
      addTearDown(() async {
        api.close();
        await srv.close(force: true);
      });

      await expectLater(api.changes(0), completes);
    });

    test('VersionMismatchException when changes response carries version 2',
        () async {
      final (srv, url) = await startServer((_) => Response.ok(
            '{"notes":[],"latestSeq":0}',
            headers: {
              'content-type': 'application/json',
              'x-librenotes-api-version': '2',
            },
          ));
      final api = SyncApi(baseUrl: url, token: 'tok');
      addTearDown(() async {
        api.close();
        await srv.close(force: true);
      });

      await expectLater(
        api.changes(0),
        throwsA(isA<VersionMismatchException>()),
      );
    });
  });
}
