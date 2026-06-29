import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../data/database.dart';
import '../data/notes_repository.dart';
import '../format.dart';
import '../theme.dart';
import 'trash_page.dart';

/// Archived notes — hidden from the main list but not deleted.
/// Per note: restore to active, or move to trash.
class ArchivePage extends StatelessWidget {
  const ArchivePage({super.key, required this.repo, this.onChanged});

  final NotesRepository repo;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NotallyColors.background,
      appBar: AppBar(
        backgroundColor: NotallyColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: NotallyColors.textPrimary),
        title: const Text(
          'Archive',
          style: TextStyle(
              color: NotallyColors.textBright,
              fontSize: 20,
              fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Trash',
            color: NotallyColors.textFaint,
            iconSize: 22,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TrashPage(repo: repo, onChanged: onChanged),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<NoteRow>>(
        stream: repo.watchArchive(),
        builder: (context, snapshot) {
          final notes = snapshot.data ?? const <NoteRow>[];
          if (notes.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.archive_outlined,
                      size: 56, color: NotallyColors.textFaint),
                  SizedBox(height: 16),
                  Text('Archive is empty',
                      style: TextStyle(
                          color: NotallyColors.textMuted, fontSize: 17)),
                  SizedBox(height: 6),
                  Text('Archived notes appear here.',
                      style: TextStyle(
                          color: NotallyColors.textFaint, fontSize: 14)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: notes.length,
            itemBuilder: (_, i) => _ArchiveItem(
              note: notes[i],
              repo: repo,
              onChanged: onChanged,
            ),
          );
        },
      ),
    );
  }
}

class _ArchiveItem extends StatelessWidget {
  const _ArchiveItem({required this.note, required this.repo, this.onChanged});

  final NoteRow note;
  final NotesRepository repo;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final preview = previewText(note.body);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: NotallyColors.card,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _ArchivedNoteView(
                note: note,
                repo: repo,
                onChanged: onChanged,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (note.title.isNotEmpty)
                        Text(
                          note.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: NotallyColors.textBright, fontSize: 15),
                        ),
                      if (note.title.isNotEmpty && preview.isNotEmpty)
                        const SizedBox(height: 4),
                      if (preview.isNotEmpty)
                        Text(
                          preview,
                          maxLines: note.title.isEmpty ? 3 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: note.title.isEmpty
                                  ? NotallyColors.textBright
                                  : NotallyColors.textMuted,
                              fontSize: note.title.isEmpty ? 15 : 13),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        'Archived ${relativeTime(note.updatedAt)}',
                        style: const TextStyle(
                            color: NotallyColors.textFaint, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    IconButton(
                      tooltip: 'Restore',
                      icon: const Icon(Icons.unarchive_outlined, size: 20),
                      color: NotallyColors.accent,
                      onPressed: () async {
                        await repo.unarchiveNote(note.id);
                        onChanged?.call();
                      },
                    ),
                    IconButton(
                      tooltip: 'Move to trash',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: NotallyColors.textFaint,
                      onPressed: () async {
                        await repo.deleteNote(note.id);
                        onChanged?.call();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArchivedNoteView extends StatelessWidget {
  const _ArchivedNoteView({
    required this.note,
    required this.repo,
    this.onChanged,
  });

  final NoteRow note;
  final NotesRepository repo;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NotallyColors.background,
      appBar: AppBar(
        backgroundColor: NotallyColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: NotallyColors.textPrimary),
        title: Text(
          note.title.isEmpty ? 'Archived note' : note.title,
          style: const TextStyle(
              color: NotallyColors.textBright,
              fontSize: 18,
              fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Restore',
            icon: const Icon(Icons.unarchive_outlined),
            color: NotallyColors.accent,
            onPressed: () async {
              await repo.unarchiveNote(note.id);
              onChanged?.call();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          IconButton(
            tooltip: 'Move to trash',
            icon: const Icon(Icons.delete_outline),
            color: NotallyColors.textFaint,
            onPressed: () async {
              await repo.deleteNote(note.id);
              onChanged?.call();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (note.title.isNotEmpty) ...[
                Text(
                  note.title,
                  style: const TextStyle(
                    color: NotallyColors.textBright,
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                'Archived ${relativeTime(note.updatedAt)}',
                style: const TextStyle(
                    color: NotallyColors.textFaint, fontSize: 13),
              ),
              const SizedBox(height: 20),
              if (note.body.trim().isEmpty)
                const Text(
                  'No content.',
                  style: TextStyle(
                      color: NotallyColors.textFaint, fontSize: 15),
                )
              else
                Markdown(
                  data: note.body,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  styleSheet: notallyMarkdownStyle(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
