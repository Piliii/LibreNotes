import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:notally_core/notally_core.dart';
import 'package:notally_server/api.dart';
import 'package:notally_server/db.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

/// HTTP-layer tests: routing, bearer-token auth, status-code mapping
/// (200 vs 409 vs 400), and error handling. The conflict/rev logic itself is
/// covered in db_test.dart; here we check the wire contract on top of it.
void main() {
  late NotesDb db;
  late HttpServer server;
  late String baseUrl;
  const token = 'secret-token';
  const auth = {'authorization': 'Bearer $token'};

  Uri u(String path) => Uri.parse('$baseUrl$path');

  String pushBody({String cipher = 'Y2lwaGVy', String nonce = 'bm9uY2U=', int baseRev = 0}) =>
      jsonEncode({'ciphertext': cipher, 'nonce': nonce, 'baseRev': baseRev});

  setUp(() async {
    db = NotesDb.open(':memory:');
    server = await shelf_io.serve(buildApi(db, token), 'localhost', 0);
    baseUrl = 'http://localhost:${server.port}';
  });

  tearDown(() async {
    await server.close(force: true);
    db.close();
  });

  group('auth', () {
    test('/health is reachable without a token', () async {
      final r = await http.get(u('/health'));
      expect(r.statusCode, 200);
      expect(jsonDecode(r.body), {'ok': true});
    });

    test('protected routes reject a missing token with 401', () async {
      final r = await http.get(u('/changes?since=0'));
      expect(r.statusCode, 401);
    });

    test('protected routes reject a wrong token with 401', () async {
      final r = await http.get(
        u('/changes?since=0'),
        headers: {'authorization': 'Bearer nope'},
      );
      expect(r.statusCode, 401);
    });
  });

  group('notes', () {
    test('create returns 200 applied with rev/seq 1', () async {
      final r = await http.put(u('/notes/n1'), headers: auth, body: pushBody());
      expect(r.statusCode, 200);
      final result = PushResult.fromJson(jsonDecode(r.body));
      expect(result.status, PushStatus.applied);
      expect(result.note.rev, 1);
      expect(result.note.seq, 1);
    });

    test('stale baseRev maps to HTTP 409 with the server version', () async {
      await http.put(u('/notes/n1'), headers: auth, body: pushBody()); // rev 1
      await http.put(u('/notes/n1'),
          headers: auth, body: pushBody(cipher: 'dXBkYXRl', baseRev: 1)); // rev 2

      final r = await http.put(u('/notes/n1'),
          headers: auth, body: pushBody(baseRev: 1)); // stale
      expect(r.statusCode, 409);
      final result = PushResult.fromJson(jsonDecode(r.body));
      expect(result.status, PushStatus.conflict);
      expect(result.note.rev, 2);
    });

    test('malformed JSON body is a 400, not a 500', () async {
      final r = await http.put(u('/notes/n1'), headers: auth, body: 'not json');
      expect(r.statusCode, 400);
    });

    test('non-base64 ciphertext is a 400, not a 500', () async {
      final r = await http.put(u('/notes/n1'),
          headers: auth,
          body: jsonEncode({'ciphertext': '!!!', 'nonce': '!!!', 'baseRev': 0}));
      expect(r.statusCode, 400);
    });

    test('delete without baseRev is a 400', () async {
      await http.put(u('/notes/n1'), headers: auth, body: pushBody());
      final r = await http.delete(u('/notes/n1'), headers: auth);
      expect(r.statusCode, 400);
    });

    test('delete with the right baseRev tombstones (200)', () async {
      await http.put(u('/notes/n1'), headers: auth, body: pushBody());
      final r = await http.delete(u('/notes/n1?baseRev=1'), headers: auth);
      expect(r.statusCode, 200);
      final result = PushResult.fromJson(jsonDecode(r.body));
      expect(result.note.deleted, isTrue);
    });
  });

  group('changes', () {
    test('returns notes after the cursor plus latestSeq', () async {
      await http.put(u('/notes/a'), headers: auth, body: pushBody()); // seq 1
      await http.put(u('/notes/b'), headers: auth, body: pushBody()); // seq 2

      final r = await http.get(u('/changes?since=1'), headers: auth);
      expect(r.statusCode, 200);
      final resp = ChangesResponse.fromJson(jsonDecode(r.body));
      expect(resp.notes.map((n) => n.id), ['b']);
      expect(resp.latestSeq, 2);
    });

    test('a non-numeric since is treated as 0', () async {
      await http.put(u('/notes/a'), headers: auth, body: pushBody());
      final r = await http.get(u('/changes?since=oops'), headers: auth);
      expect(r.statusCode, 200);
      final resp = ChangesResponse.fromJson(jsonDecode(r.body));
      expect(resp.notes.map((n) => n.id), ['a']);
    });
  });

  group('keystore', () {
    test('is 404 before anything is uploaded', () async {
      final r = await http.get(u('/keystore'), headers: auth);
      expect(r.statusCode, 404);
    });

    test('round-trips through PUT then GET', () async {
      final ks = Keystore(
        wrappedDek: utf8.encode('wrapped'),
        salt: utf8.encode('salt'),
        kdfMemory: 19456,
        kdfIterations: 2,
        kdfParallelism: 1,
      );
      final put = await http.put(u('/keystore'),
          headers: auth, body: jsonEncode(ks.toJson()));
      expect(put.statusCode, 200);

      final get = await http.get(u('/keystore'), headers: auth);
      expect(get.statusCode, 200);
      final got = Keystore.fromJson(jsonDecode(get.body));
      expect(got.wrappedDek, ks.wrappedDek);
      expect(got.kdfMemory, 19456);
    });

    test('malformed keystore body is a 400', () async {
      final r = await http.put(u('/keystore'),
          headers: auth, body: jsonEncode({'wrappedDek': 5}));
      expect(r.statusCode, 400);
    });
  });
}
