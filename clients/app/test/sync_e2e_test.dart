import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:notally_server/api.dart';
import 'package:notally_server/db.dart';

import 'package:librenotes/data/database.dart';
import 'package:librenotes/data/notes_repository.dart';
import 'package:librenotes/sync/sync_service.dart';

/// End-to-end sync test. Boots the *real* shelf server in-process (SQLite
/// `:memory:`, ephemeral port) and drives two independent [SyncService]
/// instances — two "devices", each with its own in-memory Drift store — through
/// the full encrypted round-trip: push, delta-pull, conflict, and tombstone.
///
/// This stands in for the manual two-device LAN check: every layer is exercised
/// for real (HTTP, the server's rev/seq logic, Argon2id + XChaCha20-Poly1305),
/// and the server only ever sees ciphertext.
void main() {
  late NotesDb serverDb;
  late HttpServer server;
  late String baseUrl;
  const token = 'test-token';
  const passphrase = 'correct horse battery staple';

  /// One simulated device: a fresh local store + repo + sync engine.
  late _Device dev1;
  late _Device dev2;

  setUp(() async {
    // The two devices each open their own in-memory store; that's intentional,
    // so silence drift's "multiple databases" heuristic warning.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    serverDb = NotesDb.open(':memory:');
    server = await shelf_io.serve(buildApi(serverDb, token), 'localhost', 0);
    baseUrl = 'http://localhost:${server.port}';

    // dev1 connects first: it bootstraps and uploads the keystore.
    dev1 = await _Device.connect(baseUrl, token, passphrase);
    // dev2 is a "new device": it unlocks the same keystore with the passphrase.
    dev2 = await _Device.connect(baseUrl, token, passphrase);
  });

  tearDown(() async {
    await dev1.dispose();
    await dev2.dispose();
    await server.close(force: true);
    serverDb.close();
  });

  test('a note created on one device shows up decrypted on the other', () async {
    final id = await dev1.write(title: 'Groceries', body: 'milk, eggs');
    await dev1.sync.syncNow();

    // Server stores ciphertext only — the plaintext must not be on the wire.
    final stored = serverDb.getNote(id)!;
    expect(stored.deleted, isFalse);
    expect(String.fromCharCodes(stored.ciphertext).contains('Groceries'),
        isFalse);

    await dev2.sync.syncNow();
    final pulled = await dev2.repo.getNote(id);
    expect(pulled, isNotNull);
    expect(pulled!.title, 'Groceries');
    expect(pulled.body, 'milk, eggs');
    expect(pulled.dirty, isFalse);
    expect(pulled.rev, 1);
  });

  test('divergent edits raise a conflict; keepLocal makes our version win',
      () async {
    final id = await dev1.write(title: 'Plan', body: 'v1');
    await dev1.sync.syncNow();
    await dev2.sync.syncNow(); // both now hold rev 1

    // Edit on both devices before either re-syncs.
    await dev1.repo.updateContent(id, body: 'dev1 edit');
    await dev2.repo.updateContent(id, body: 'dev2 edit');

    // dev1 pushes first and wins the rev bump.
    await dev1.sync.syncNow();
    expect(dev1.sync.conflicts.value, isEmpty);

    // dev2 pulls dev1's change while holding its own dirty edit -> conflict.
    await dev2.sync.syncNow();
    expect(dev2.sync.conflicts.value, hasLength(1));
    final conflict = dev2.sync.conflicts.value.single;
    expect(conflict.id, id);
    expect(conflict.local.body, 'dev2 edit'); // our side
    expect(conflict.remote.body, 'dev1 edit'); // the server's side

    // Resolve in favour of the local edit.
    await dev2.sync.keepLocal(id);
    expect(dev2.sync.conflicts.value, isEmpty);

    // dev1 pulls and converges on dev2's resolved version.
    await dev1.sync.syncNow();
    final onDev1 = await dev1.repo.getNote(id);
    expect(onDev1!.body, 'dev2 edit');
    expect(onDev1.dirty, isFalse);
  });

  test('keepRemote discards the local edit and adopts the server version',
      () async {
    final id = await dev1.write(title: 'Notes', body: 'base');
    await dev1.sync.syncNow();
    await dev2.sync.syncNow();

    await dev1.repo.updateContent(id, body: 'from dev1');
    await dev2.repo.updateContent(id, body: 'from dev2');

    await dev1.sync.syncNow();
    await dev2.sync.syncNow();
    expect(dev2.sync.conflicts.value, hasLength(1));

    await dev2.sync.keepRemote(id);
    expect(dev2.sync.conflicts.value, isEmpty);

    final resolved = await dev2.repo.getNote(id);
    expect(resolved!.body, 'from dev1'); // server (dev1) version won
    expect(resolved.dirty, isFalse);
  });

  test('a delete on one device propagates as a tombstone to the other',
      () async {
    final id = await dev1.write(title: 'Temp', body: 'throwaway');
    await dev1.sync.syncNow();
    await dev2.sync.syncNow();
    expect((await dev2.repo.getNote(id))!.deleted, isFalse);

    await dev1.repo.deleteNote(id);
    await dev1.sync.syncNow();
    expect(serverDb.getNote(id)!.deleted, isTrue);

    await dev2.sync.syncNow();
    final gone = await dev2.repo.getNote(id);
    expect(gone, isNotNull);
    expect(gone!.deleted, isTrue); // tombstone present, hidden from the list
  });
}

class _Device {
  _Device(this.db, this.repo, this.sync);

  final AppDatabase db;
  final NotesRepository repo;
  final SyncService sync;

  static Future<_Device> connect(
    String baseUrl,
    String token,
    String passphrase,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = NotesRepository(db);
    final sync = SyncService(repo);
    await sync.init();
    await sync.connect(baseUrl: baseUrl, token: token, passphrase: passphrase);
    return _Device(db, repo, sync);
  }

  /// Creates a note and sets its content (marking it dirty), returning the id.
  Future<String> write({required String title, required String body}) async {
    final id = await repo.createNote();
    await repo.updateContent(id, title: title, body: body);
    return id;
  }

  Future<void> dispose() async {
    sync.dispose(); // cancels the 15s auto-sync timer + closes the http client
    await db.close();
  }
}
