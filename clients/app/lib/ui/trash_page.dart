import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../data/database.dart';
import '../data/notes_repository.dart';
import '../format.dart';
import '../theme.dart';

/// Shows trashed notes with per-item restore / permanent-delete actions
/// and a top-level "Empty trash" button.
class TrashPage extends StatelessWidget {
  const TrashPage({super.key, required this.repo, this.onChanged});

  final NotesRepository repo;

  /// Called after a restore or purge so the sync service can nudge promptly.
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
          'Trash',
          style: TextStyle(
              color: NotallyColors.textBright,
              fontSize: 20,
              fontWeight: FontWeight.bold),
        ),
        actions: [_EmptyTrashButton(repo: repo, onChanged: onChanged)],
      ),
      body: StreamBuilder<List<NoteRow>>(
        stream: repo.watchTrash(),
        builder: (context, snapshot) {
          final notes = snapshot.data ?? const <NoteRow>[];
          if (notes.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_outline,
                      size: 56, color: NotallyColors.textFaint),
                  SizedBox(height: 16),
                  Text('Trash is empty',
                      style: TextStyle(
                          color: NotallyColors.textMuted, fontSize: 17)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: notes.length,
            itemBuilder: (_, i) => _TrashItem(
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

class _EmptyTrashButton extends StatelessWidget {
  const _EmptyTrashButton({required this.repo, this.onChanged});
  final NotesRepository repo;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NoteRow>>(
      stream: repo.watchTrash(),
      builder: (context, snapshot) {
        if ((snapshot.data ?? []).isEmpty) return const SizedBox.shrink();
        return TextButton(
          onPressed: () => _confirm(context),
          child: const Text('Empty',
              style: TextStyle(color: NotallyColors.accent)),
        );
      },
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NotallyColors.surface,
        title: const Text('Empty trash?',
            style: TextStyle(color: NotallyColors.textBright)),
        content: const Text(
          'This permanently deletes all notes in the trash and cannot be undone.',
          style: TextStyle(color: NotallyColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: NotallyColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Empty trash',
                style: TextStyle(color: NotallyColors.accent)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await repo.emptyTrash();
      onChanged?.call();
    }
  }
}

class _TrashItem extends StatelessWidget {
  const _TrashItem({required this.note, required this.repo, this.onChanged});

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
              builder: (_) => _TrashedNoteView(
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
                      Text(
                        note.title.isEmpty ? 'Untitled' : note.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: NotallyColors.textBright, fontSize: 15),
                      ),
                      if (preview.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: NotallyColors.textMuted, fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'Deleted ${relativeTime(note.updatedAt)}',
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
                      icon: const Icon(Icons.restore, size: 20),
                      color: NotallyColors.accent,
                      onPressed: () async {
                        await repo.restoreNote(note.id);
                        onChanged?.call();
                      },
                    ),
                    IconButton(
                      tooltip: 'Delete permanently',
                      icon: const Icon(Icons.delete_forever_outlined, size: 20),
                      color: NotallyColors.textFaint,
                      onPressed: () => _confirmPermanentDelete(context),
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

  Future<void> _confirmPermanentDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NotallyColors.surface,
        title: const Text('Delete permanently?',
            style: TextStyle(color: NotallyColors.textBright)),
        content: const Text('This note will be gone forever.',
            style: TextStyle(color: NotallyColors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: NotallyColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete forever',
                style: TextStyle(color: NotallyColors.accent)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await repo.markForPurge(note.id);
      onChanged?.call();
    }
  }
}

/// Read-only view of a trashed note's full content.
class _TrashedNoteView extends StatelessWidget {
  const _TrashedNoteView({
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
          note.title.isEmpty ? 'Untitled' : note.title,
          style: const TextStyle(
              color: NotallyColors.textBright,
              fontSize: 18,
              fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Restore',
            icon: const Icon(Icons.restore),
            color: NotallyColors.accent,
            onPressed: () async {
              await repo.restoreNote(note.id);
              onChanged?.call();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          IconButton(
            tooltip: 'Delete permanently',
            icon: const Icon(Icons.delete_forever_outlined),
            color: NotallyColors.textFaint,
            onPressed: () => _confirmPermanentDelete(context),
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
                'Deleted ${relativeTime(note.updatedAt)}',
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

  Future<void> _confirmPermanentDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NotallyColors.surface,
        title: const Text('Delete permanently?',
            style: TextStyle(color: NotallyColors.textBright)),
        content: const Text('This note will be gone forever.',
            style: TextStyle(color: NotallyColors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: NotallyColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete forever',
                style: TextStyle(color: NotallyColors.accent)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await repo.markForPurge(note.id);
      onChanged?.call();
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}
