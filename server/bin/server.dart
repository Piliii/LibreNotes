import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf_io.dart' as io;

import 'package:notally_server/api.dart';
import 'package:notally_server/db.dart';

/// Entry point for the Notally sync server.
///
/// Config via environment variables:
///   NOTALLY_DATA   directory for the SQLite db + token file (default ./data)
///   NOTALLY_HOST   bind address (default 0.0.0.0 — your LAN; never the WAN)
///   NOTALLY_PORT   port (default 8787)
///   NOTALLY_TOKEN  bearer token; if unset, one is generated and persisted
Future<void> main() async {
  final dataDir = Directory(
    Platform.environment['NOTALLY_DATA'] ?? 'data',
  )..createSync(recursive: true);

  final host = Platform.environment['NOTALLY_HOST'] ?? '0.0.0.0';
  final port = int.tryParse(Platform.environment['NOTALLY_PORT'] ?? '') ?? 8787;
  final token = _resolveToken(dataDir);

  final db = NotesDb.open('${dataDir.path}/notally.db');
  final handler = buildApi(db, token);

  final server = await io.serve(handler, host, port);
  stdout.writeln('Notally sync server listening on http://$host:${server.port}');
  stdout.writeln('Data dir: ${dataDir.path}');
  stdout.writeln('Auth token: $token');

  // Graceful shutdown: stop accepting connections, let in-flight requests
  // finish, then close the db so SQLite checkpoints its WAL cleanly. Handle
  // SIGTERM too — that's what `systemctl stop` sends.
  var stopping = false;
  Future<void> shutdown(ProcessSignal signal) async {
    if (stopping) return; // ignore a second signal while we're already closing
    stopping = true;
    stdout.writeln('\nReceived $signal, shutting down…');
    await server.close();
    db.close();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen(shutdown);
  ProcessSignal.sigterm.watch().listen(shutdown);
}

/// Uses NOTALLY_TOKEN if set, otherwise reads/creates a persisted random token.
String _resolveToken(Directory dataDir) {
  final fromEnv = Platform.environment['NOTALLY_TOKEN'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;

  final file = File('${dataDir.path}/token');
  if (file.existsSync()) return file.readAsStringSync().trim();

  final rng = Random.secure();
  final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
  final token = base64Url.encode(bytes).replaceAll('=', '');
  file.writeAsStringSync(token);
  return token;
}
