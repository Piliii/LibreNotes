import 'dart:convert';

import 'package:notally_core/notally_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'db.dart';

/// Builds the Notally HTTP API. [token] gates every route except `/health`.
Handler buildApi(NotesDb db, String token) {
  final router = Router();

  // Liveness check — unauthenticated so you can curl it during setup.
  router.get('/health', (Request _) => _json({'ok': true}));

  // Delta pull: everything changed after the client's cursor.
  router.get('/changes', (Request req) {
    final since = int.tryParse(req.url.queryParameters['since'] ?? '0') ?? 0;
    final response = ChangesResponse(
      notes: db.changesSince(since),
      latestSeq: db.latestSeq(),
    );
    return _json(response.toJson());
  });

  // Create or update a note. 409 on a stale baseRev (conflict).
  router.put('/notes/<id>', (Request req, String id) async {
    final PushRequest push;
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      push = PushRequest.fromJson(body);
    } catch (_) {
      return _json({'error': 'invalid request body'}, status: 400);
    }
    final result = db.push(id, push.ciphertext, push.nonce, push.baseRev);
    return _json(
      result.toJson(),
      status: result.status == PushStatus.conflict ? 409 : 200,
    );
  });

  // Permanently purge a note from all devices' trash. No conflict check.
  router.delete('/notes/<id>/purge', (Request _, String id) {
    db.purge(id);
    return _json({'ok': true});
  });

  // Tombstone a note. Same conflict semantics as a write.
  router.delete('/notes/<id>', (Request req, String id) {
    final baseRev = int.tryParse(req.url.queryParameters['baseRev'] ?? '');
    if (baseRev == null) {
      return _json({'error': 'baseRev query param required'}, status: 400);
    }
    final result = db.tombstone(id, baseRev);
    return _json(
      result.toJson(),
      status: result.status == PushStatus.conflict ? 409 : 200,
    );
  });

  // Encrypted key bundle (wrapped DEK + KDF salt/params).
  router.get('/keystore', (Request _) {
    final ks = db.getKeystore();
    if (ks == null) return _json({'error': 'no keystore'}, status: 404);
    return _json(ks.toJson());
  });

  router.put('/keystore', (Request req) async {
    final Keystore ks;
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      ks = Keystore.fromJson(body);
    } catch (_) {
      return _json({'error': 'invalid request body'}, status: 400);
    }
    db.setKeystore(ks);
    return _json({'ok': true});
  });

  final handler = const Pipeline()
      .addMiddleware(_authMiddleware(token))
      .addHandler(router.call);

  return handler;
}

/// Requires `Authorization: Bearer <token>` on every route except `/health`.
Middleware _authMiddleware(String token) {
  final expected = 'Bearer $token';
  return (Handler inner) {
    return (Request req) {
      if (req.url.path == 'health') return inner(req);
      if (req.headers['authorization'] != expected) {
        return _json({'error': 'unauthorized'}, status: 401);
      }
      return inner(req);
    };
  };
}

Response _json(Object? data, {int status = 200}) => Response(
  status,
  body: jsonEncode(data),
  headers: {'content-type': 'application/json'},
);
