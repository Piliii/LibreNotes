import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/notes_repository.dart';
import '../format.dart';
import '../sync/sync_service.dart';
import '../theme.dart';
import 'note_editor.dart';
import 'sync_settings_page.dart';
import 'trash_page.dart';

/// Root screen. Desktop = list left / editor right; mobile = 2-up card grid.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repo, required this.sync});

  final NotesRepository repo;
  final SyncService sync;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _desktopBreakpoint = 720.0;

  String? _selectedId;
  double _sidebarWidth = 280;

  Future<void> _newNote() async {
    final id = await widget.repo.createNote();
    setState(() => _selectedId = id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<NoteRow>>(
        stream: widget.repo.watchNotes(),
        builder: (context, snapshot) {
          final notes = snapshot.data ?? const <NoteRow>[];
          final isDesktop =
              MediaQuery.sizeOf(context).width >= _desktopBreakpoint;
          return isDesktop ? _desktop(notes) : _mobile(notes);
        },
      ),
    );
  }

  // ---- Desktop -------------------------------------------------------------

  Widget _desktop(List<NoteRow> notes) {
    final selected = notes.any((n) => n.id == _selectedId) ? _selectedId : null;
    return Row(
      children: [
        SizedBox(
          width: _sidebarWidth,
          child: _Sidebar(
            notes: notes,
            selectedId: selected,
            onSelect: (id) => setState(() => _selectedId = id),
            onNew: _newNote,
            repo: widget.repo,
            sync: widget.sync,
          ),
        ),
        _ResizeHandle(
          onDrag: (dx) => setState(
            () => _sidebarWidth = (_sidebarWidth + dx).clamp(180.0, 600.0),
          ),
        ),
        Expanded(
          child: selected == null
              ? const _EmptyEditor()
              : NoteEditor(
                  key: ValueKey(selected),
                  repo: widget.repo,
                  noteId: selected,
                  onEdited: widget.sync.nudge,
                  onDeleted: () => setState(() => _selectedId = null),
                ),
        ),
      ],
    );
  }

  // ---- Mobile --------------------------------------------------------------

  Widget _mobile(List<NoteRow> notes) {
    return Scaffold(
      backgroundColor: NotallyColors.background,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: NotallyColors.accent,
        foregroundColor: Colors.white,
        onPressed: () async {
          final id = await widget.repo.createNote();
          if (!mounted) return;
          _openMobile(id);
        },
        icon: const Icon(Icons.add),
        label: const Text('New note'),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          const Text(
                            'Notes',
                            style: TextStyle(
                              color: NotallyColors.textBright,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (notes.isNotEmpty)
                            Text(
                              '${notes.length}',
                              style: const TextStyle(
                                  color: NotallyColors.textFaint, fontSize: 18),
                            ),
                        ],
                      ),
                    ),
                    _TrashButton(repo: widget.repo, onChanged: widget.sync.nudge),
                    _RefreshButton(sync: widget.sync),
                    _SyncButton(sync: widget.sync),
                  ],
                ),
              ),
            ),
            if (notes.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyHint(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.78,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _NoteCard(
                      note: notes[i],
                      onTap: () => _openMobile(notes[i].id),
                    ),
                    childCount: notes.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openMobile(String id) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoteEditorPage(
          repo: widget.repo,
          noteId: id,
          onEdited: widget.sync.nudge,
        ),
      ),
    );
  }
}

// --- Desktop sidebar --------------------------------------------------------

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.notes,
    required this.selectedId,
    required this.onSelect,
    required this.onNew,
    required this.repo,
    required this.sync,
  });

  final List<NoteRow> notes;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onNew;
  final NotesRepository repo;
  final SyncService sync;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: NotallyColors.surface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: NotallyColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Text('Notes',
                        style: TextStyle(
                            color: NotallyColors.textBright,
                            fontSize: 24,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    _TrashButton(repo: repo, onChanged: sync.nudge),
                    _RefreshButton(sync: sync),
                    _SyncButton(sync: sync),
                  ],
                ),
                const SizedBox(height: 15),
                FilledButton(
                  onPressed: onNew,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('+ New Note'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: notes.isEmpty
                ? const Center(
                    child: Text('No notes yet',
                        style: TextStyle(
                            color: NotallyColors.textFaint, fontSize: 14)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: notes.length,
                    itemBuilder: (_, i) {
                      final n = notes[i];
                      return _NoteListItem(
                        note: n,
                        active: n.id == selectedId,
                        onTap: () => onSelect(n.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _NoteListItem extends StatelessWidget {
  const _NoteListItem(
      {required this.note, required this.active, required this.onTap});

  final NoteRow note;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: active ? NotallyColors.cardActive : NotallyColors.card,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(
                  color: active ? NotallyColors.accent : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        note.title.isEmpty ? 'Untitled' : note.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: NotallyColors.textBright, fontSize: 15),
                      ),
                    ),
                    if (note.pinned)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.push_pin,
                            size: 13, color: NotallyColors.accent),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _previewOrPlaceholder(note.body),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: NotallyColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Mobile card ------------------------------------------------------------

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.onTap});

  final NoteRow note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NotallyColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2F2F2F)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.title.isEmpty ? 'Untitled' : note.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: NotallyColors.textBright,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.25),
                    ),
                  ),
                  if (note.pinned)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.push_pin,
                          size: 15, color: NotallyColors.accent),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  _previewOrPlaceholder(note.body),
                  overflow: TextOverflow.fade,
                  style: const TextStyle(
                      color: NotallyColors.textMuted,
                      fontSize: 13,
                      height: 1.45),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                relativeTime(note.updatedAt),
                style: const TextStyle(
                    color: NotallyColors.textFaint, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Shared bits ------------------------------------------------------------

/// Opens the trash screen. Always visible so trashed notes are always accessible.
class _TrashButton extends StatelessWidget {
  const _TrashButton({required this.repo, this.onChanged});

  final NotesRepository repo;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Trash',
      color: NotallyColors.textFaint,
      iconSize: 22,
      icon: const Icon(Icons.delete_outline),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TrashPage(repo: repo, onChanged: onChanged),
        ),
      ),
    );
  }
}

/// Manual "pull now" button: triggers a sync immediately instead of waiting
/// for the next poll. Hidden until sync is configured and unlocked; disabled
/// while a sync is already running.
class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.sync});

  final SyncService sync;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: sync.status,
      builder: (context, status, __) {
        final ready = status.state != SyncState.notConfigured &&
            status.state != SyncState.locked;
        if (!ready) return const SizedBox.shrink();
        final syncing = status.state == SyncState.syncing;
        return IconButton(
          tooltip: 'Refresh now',
          color: NotallyColors.textFaint,
          iconSize: 22,
          icon: const Icon(Icons.refresh),
          onPressed: syncing ? null : sync.syncNow,
        );
      },
    );
  }
}

/// Header entry point into sync: reflects the live [SyncStatus] as an icon and
/// overlays a badge with the number of unresolved conflicts. Tapping opens the
/// connect/unlock + settings screen.
class _SyncButton extends StatelessWidget {
  const _SyncButton({required this.sync});

  final SyncService sync;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: sync.status,
      builder: (context, status, __) {
        final (icon, color) = _describe(status.state);
        return ValueListenableBuilder<List<SyncConflict>>(
          valueListenable: sync.conflicts,
          builder: (context, conflicts, __) {
            return Tooltip(
              message: _tooltip(status, conflicts.length),
              child: IconButton(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, color: color, size: 22),
                    if (conflicts.isNotEmpty)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: NotallyColors.accent,
                            shape: BoxShape.circle,
                          ),
                          constraints:
                              const BoxConstraints(minWidth: 15, minHeight: 15),
                          child: Text(
                            '${conflicts.length}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                height: 1),
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SyncSettingsPage(service: sync),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  (IconData, Color) _describe(SyncState state) {
    switch (state) {
      case SyncState.notConfigured:
        return (Icons.cloud_off, NotallyColors.textFaint);
      case SyncState.locked:
        return (Icons.lock_outline, NotallyColors.accent);
      case SyncState.syncing:
        return (Icons.sync, NotallyColors.accent);
      case SyncState.ok:
        return (Icons.cloud_done, const Color(0xFF4CAF50));
      case SyncState.offline:
        return (Icons.cloud_off, NotallyColors.textMuted);
      case SyncState.error:
        return (Icons.error_outline, NotallyColors.accent);
    }
  }

  String _tooltip(SyncStatus s, int conflicts) {
    if (conflicts > 0) return '$conflicts conflict(s) to resolve';
    switch (s.state) {
      case SyncState.notConfigured:
        return 'Sync — not connected';
      case SyncState.locked:
        return 'Sync — locked';
      case SyncState.syncing:
        return s.message ?? 'Syncing…';
      case SyncState.ok:
        return 'Synced';
      case SyncState.offline:
        return 'Offline';
      case SyncState.error:
        return s.message ?? 'Sync error';
    }
  }
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.onDrag});
  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
        child: Container(width: 6, color: NotallyColors.border),
      ),
    );
  }
}

class _EmptyEditor extends StatelessWidget {
  const _EmptyEditor();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Select a note, or create a new one.',
          style: TextStyle(color: NotallyColors.textFaint, fontSize: 15)),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.note_add_outlined,
              size: 56, color: NotallyColors.textFaint),
          SizedBox(height: 16),
          Text('No notes yet',
              style:
                  TextStyle(color: NotallyColors.textMuted, fontSize: 17)),
          SizedBox(height: 6),
          Text('Tap “New note” to get started.',
              style:
                  TextStyle(color: NotallyColors.textFaint, fontSize: 14)),
        ],
      ),
    );
  }
}

String _previewOrPlaceholder(String body) {
  final p = previewText(body);
  return p.isEmpty ? 'No additional text' : p;
}
