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
/// YAML-style front matter for an exported note; '' when there's nothing
/// to say, so plain notes export exactly as before.
String frontMatter(String folder, List<String> tags) {
  if (folder.isEmpty && tags.isEmpty) return '';
  return [
    '---',
    if (folder.isNotEmpty) 'folder: $folder',
    if (tags.isNotEmpty) 'tags: [${tags.join(', ')}]',
    '---',
    '',
  ].join('\n');
}

/// Reads back what [frontMatter] writes (only the `folder` and `tags` keys;
/// other keys are ignored). Text without a leading `---` block is returned
/// untouched as [rest].
({String folder, List<String> tags, String rest}) parseFrontMatter(
    String raw) {
  final m = RegExp(r'^---\r?\n([\s\S]*?)\r?\n---\r?\n?').firstMatch(raw);
  if (m == null) return (folder: '', tags: const [], rest: raw);
  var folder = '';
  var tags = <String>[];
  for (final line in m.group(1)!.split('\n')) {
    final i = line.indexOf(':');
    if (i < 0) continue;
    final key = line.substring(0, i).trim();
    final value = line.substring(i + 1).trim();
    if (key == 'folder') folder = value;
    if (key == 'tags') {
      tags = value
          .replaceAll(RegExp(r'^\[|\]$'), '')
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
    }
  }
  return (folder: folder, tags: tags, rest: raw.substring(m.end));
}

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
        // Folders become subdirectories; the front matter is what import
        // reads back (it picks files, so it can't see the directory).
        final sub = note.folder.isEmpty ? '' : '${_safe(note.folder)}/';
        if (sub.isNotEmpty) await Directory('$dir/$sub').create();
        final name = sub + _fileNameFor(note, usedNames, sub);
        final body = await _exportImages(note, dir, sub.isEmpty ? '' : '../');
        final content =
            note.title.isEmpty ? body : '# ${note.title}\n\n$body';
        await File('$dir/$name')
            .writeAsString(frontMatter(note.folder, note.tags) + content);
      }
      _finish('Exported ${notes.length} note(s) to $dir', isError: false);
    } catch (e) {
      _finish('Export failed: $e', isError: true);
    }
  }

  /// Builds a filesystem-safe, unique `.md` filename from a note's title (or
  /// its first non-blank body line, if untitled).
  String _fileNameFor(NoteRow note, Set<String> usedNames, String dir) {
    var base = note.title.trim();
    if (base.isEmpty) {
      base = note.body
          .split('\n')
          .map((l) => l.trim())
          .firstWhere((l) => l.isNotEmpty, orElse: () => 'note');
    }
    var slug = _safe(base);
    if (slug.length > 60) slug = slug.substring(0, 60);

    var name = '$slug.md';
    var suffix = 2;
    while (!usedNames.add('$dir$name')) {
      name = '$slug ($suffix).md';
      suffix++;
    }
    return name;
  }

  /// Writes the note's images (decrypted) to `<dir>/attachments/` and
  /// points its links at those files. An image that isn't on this device
  /// keeps its `attachment:` link.
  Future<String> _exportImages(NoteRow note, String dir, String up) async {
    var body = note.body;
    for (final m in attachmentLinkPattern.allMatches(note.body)) {
      final id = m.group(1)!;
      final bytes = await widget.repo.loadImage(id, note.id);
      if (bytes == null) continue;
      await Directory('$dir/attachments').create();
      await File('$dir/attachments/$id').writeAsBytes(bytes);
      body = body.replaceAll('(attachment:$id)', '(${up}attachments/$id)');
    }
    return body;
  }

  static String _safe(String s) {
    final out = s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return out.isEmpty || out == '.' || out == '..' ? 'note' : out;
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
        final (:folder, :tags, :rest) = parseFrontMatter(raw);
        final (title, body) = _splitTitle(rest);
        final id = await widget.repo.createNote();
        await widget.repo.updateContent(id, title: title, body: body);
        if (folder.isNotEmpty) await widget.repo.setFolder(id, folder);
        if (tags.isNotEmpty) await widget.repo.setTags(id, tags);
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
            Text(
              'Export',
              style: TextStyle(
                  color: NotallyColors.textBright,
                  fontWeight: FontWeight.w600,
                  fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
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
            Text(
              'Import',
              style: TextStyle(
                  color: NotallyColors.textBright,
                  fontWeight: FontWeight.w600,
                  fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
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
