import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/notes_repository.dart';
import '../theme.dart';

/// Manual, opt-in interop with the outside world — an explicit crypto
/// boundary. Export decrypts notes on the fly and writes them out as plain
/// `.md` files, so notes are never locked to LibreNotes. Import reads `.md`
/// files from other apps and immediately encrypts them into the local store.
/// Decryption/encryption only ever happens here, at this user-triggered
/// boundary — nothing sits in plaintext on disk automatically.
class ImportExportPage extends StatefulWidget {
  const ImportExportPage({super.key, required this.repo});

  final NotesRepository repo;

  @override
  State<ImportExportPage> createState() => _ImportExportPageState();
}

class _ImportExportPageState extends State<ImportExportPage> {
  bool _busy = false;
  String? _result;
  bool _resultIsError = false;

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final dir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose a folder to export notes into',
      );
      if (dir == null) {
        setState(() => _busy = false);
        return;
      }
      final notes = await widget.repo.getAllForExport();
      final usedNames = <String>{};
      for (final note in notes) {
        final name = _fileNameFor(note, usedNames);
        final content =
            note.title.isEmpty ? note.body : '# ${note.title}\n\n${note.body}';
        await File('$dir/$name').writeAsString(content);
      }
      _finish('Exported ${notes.length} note(s) to $dir', isError: false);
    } catch (e) {
      _finish('Export failed: $e', isError: true);
    }
  }

  /// Builds a filesystem-safe, unique `.md` filename from a note's title (or
  /// its first non-blank body line, if untitled).
  String _fileNameFor(NoteRow note, Set<String> usedNames) {
    var base = note.title.trim();
    if (base.isEmpty) {
      base = note.body
          .split('\n')
          .map((l) => l.trim())
          .firstWhere((l) => l.isNotEmpty, orElse: () => 'note');
    }
    var slug = base.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (slug.isEmpty) slug = 'note';
    if (slug.length > 60) slug = slug.substring(0, 60);

    var name = '$slug.md';
    var suffix = 2;
    while (!usedNames.add(name)) {
      name = '$slug ($suffix).md';
      suffix++;
    }
    return name;
  }

  Future<void> _import() async {
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final picked = await FilePicker.platform.pickFiles(
        dialogTitle: 'Choose markdown files to import',
        type: FileType.custom,
        allowedExtensions: ['md', 'markdown', 'txt'],
        allowMultiple: true,
      );
      if (picked == null || picked.files.isEmpty) {
        setState(() => _busy = false);
        return;
      }
      var count = 0;
      for (final file in picked.files) {
        final path = file.path;
        if (path == null) continue;
        final raw = await File(path).readAsString();
        final (title, body) = _splitTitle(raw);
        final id = await widget.repo.createNote();
        await widget.repo.updateContent(id, title: title, body: body);
        count++;
      }
      _finish('Imported $count note(s)', isError: false);
    } catch (e) {
      _finish('Import failed: $e', isError: true);
    }
  }

  /// A leading `# Heading` line becomes the title; everything else is body.
  (String, String) _splitTitle(String raw) {
    final firstBreak = raw.indexOf('\n');
    final firstLine = firstBreak == -1 ? raw : raw.substring(0, firstBreak);
    if (firstLine.trimLeft().startsWith('# ')) {
      final title = firstLine.trimLeft().substring(2).trim();
      final rest = firstBreak == -1 ? '' : raw.substring(firstBreak + 1);
      return (title, rest.trimLeft());
    }
    return ('', raw);
  }

  void _finish(String message, {required bool isError}) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = message;
      _resultIsError = isError;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NotallyColors.background,
      appBar: AppBar(
        backgroundColor: NotallyColors.surface,
        title: const Text('Import / export'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Export',
              style: TextStyle(
                  color: NotallyColors.textBright,
                  fontWeight: FontWeight.w600,
                  fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              'Decrypts every note (except trashed ones) and writes it out as a '
              'plain .md file into a folder you choose — notes stay readable '
              'outside LibreNotes.',
              style: TextStyle(color: NotallyColors.textMuted, height: 1.4),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _export,
              style:
                  FilledButton.styleFrom(backgroundColor: NotallyColors.accent),
              child: const Text('Export all notes…'),
            ),
            const SizedBox(height: 32),
            const Text(
              'Import',
              style: TextStyle(
                  color: NotallyColors.textBright,
                  fontWeight: FontWeight.w600,
                  fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              'Reads .md files and encrypts them into your local notes. A '
              'leading "# Heading" line becomes the title; the rest becomes '
              'the body.',
              style: TextStyle(color: NotallyColors.textMuted, height: 1.4),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : _import,
              child: const Text('Import markdown files…'),
            ),
            if (_busy) ...[
              const SizedBox(height: 24),
              const Center(
                child: CircularProgressIndicator(color: NotallyColors.accent),
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 24),
              Text(
                _result!,
                style: TextStyle(
                  color: _resultIsError ? NotallyColors.accent : NotallyColors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
