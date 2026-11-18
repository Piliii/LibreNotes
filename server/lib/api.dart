import 'dart:convert';
import 'dart:typed_data';

import 'package:notally_core/notally_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'db.dart';

/// Bump only for a *breaking* wire change: clients refuse to sync with a
/// server whose version is higher than theirs. Additive routes (like
/// /attachments) keep it as is, so older apps go on syncing.
const _apiVersion = 1;

/// Bump when the server gains an *additive* feature older apps can't use
/// (2 = images). Older apps keep syncing; ones from 1.7.0 on show a
/// dismissible "update the app" notice. Keep in lockstep with
/// `SyncApi.featureLevel` in the client.
const _featureLevel = 2;

/// Largest accepted attachment upload. Clients cap images at 10 MB before
/// encryption; this leaves headroom for the nonce and auth tag.
const maxAttachmentBytes = 15 * 1024 * 1024;

/// Attachment and note ids are client-generated (`<uuid>.<ext>` / uuid).
final _idPattern = RegExp(r'^[A-Za-z0-9-]{1,64}(\.[A-Za-z0-9]{1,8})?$');

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

  // Encrypted image blob, bound to the note that owns it (`?note=<id>`).
  router.put('/attachments/<id>', (Request req, String id) async {
    final noteId = req.url.queryParameters['note'] ?? '';
    if (!_idPattern.hasMatch(id) || !_idPattern.hasMatch(noteId)) {
      return _json({'error': 'invalid id'}, status: 400);
    }
    final declared = req.contentLength;
    if (declared != null && declared > maxAttachmentBytes) {
      return _json({'error': 'attachment too large'}, status: 413);
    }
    final body = BytesBuilder(copy: false);
    await for (final chunk in req.read()) {
      body.add(chunk);
      if (body.length > maxAttachmentBytes) {
        return _json({'error': 'attachment too large'}, status: 413);
      }
    }
    if (body.isEmpty) return _json({'error': 'empty body'}, status: 400);
    db.putAttachment(id, noteId, body.takeBytes());
    return _json({'ok': true});
  });

  router.get('/attachments/<id>', (Request _, String id) {
    final data = db.getAttachment(id);
    if (data == null) return _json({'error': 'not found'}, status: 404);
    return Response.ok(
      data,
      headers: {'content-type': 'application/octet-stream'},
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
      .addMiddleware(_versionMiddleware())
      .addMiddleware(_authMiddleware(token))
      .addHandler(router.call);

  return handler;
}

/// Stamps every response with the server's API version so clients can detect
/// incompatible version mismatches and show a human-readable error.
Middleware _versionMiddleware() {
  return (Handler inner) {
    return (Request req) async {
      final response = await inner(req);
      return response.change(headers: {
        'x-librenotes-api-version': '$_apiVersion',
        'x-librenotes-feature-level': '$_featureLevel',
      });
    };
  };
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
