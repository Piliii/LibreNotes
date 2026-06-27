import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/notes_repository.dart';
import '../format.dart';
import '../sync/sync_service.dart';
import '../theme.dart';
import 'note_editor.dart';
import 'sync_settings_page.dart';
import 'trash_page.dart';

enum _DesktopLayout { sidebar, tabs }

enum _NoteAction { pin, color, trash }

/// Root screen. Desktop = sidebar+editor or tabs+editor; mobile = 2-up card grid.
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
  _DesktopLayout _layout = _DesktopLayout.sidebar;
  bool _isNewNote = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.sizeOf(context).width >= _desktopBreakpoint) _newNote();
    });
  }

  Future<void> _loadPrefs() async {
    final layoutStr = await widget.repo.kvGet('pref.layout');
    final widthStr = await widget.repo.kvGet('pref.sidebarWidth');
    if (!mounted) return;
    setState(() {
      if (layoutStr == 'tabs') _layout = _DesktopLayout.tabs;
      if (widthStr != null) _sidebarWidth = double.tryParse(widthStr) ?? 280;
    });
  }

  Future<void> _newNote() async {
    final id = await widget.repo.createNote();
    setState(() {
      _selectedId = id;
      _isNewNote = true;
    });
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
    final child = switch (_layout) {
      _DesktopLayout.sidebar => _desktopSidebar(notes),
      _DesktopLayout.tabs => _desktopTabs(notes),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: KeyedSubtree(key: ValueKey(_layout), child: child),
    );
  }

  Widget _desktopSidebar(List<NoteRow> notes) {
    final selected = notes.any((n) => n.id == _selectedId) ? _selectedId : null;
    return Row(
      children: [
        SizedBox(
          width: _sidebarWidth,
          child: _Sidebar(
            notes: notes,
            selectedId: selected,
            onSelect: (id) => setState(() {
              _selectedId = id;
              _isNewNote = false;
            }),
            onNew: _newNote,
            repo: widget.repo,
            sync: widget.sync,
            onLayoutToggle: () {
              setState(() => _layout = _DesktopLayout.tabs);
              widget.repo.kvSet('pref.layout', 'tabs');
            },
            onNoteContextMenu: (note, pos) =>
                _showDesktopContextMenu(context, note, pos),
          ),
        ),
        _ResizeHandle(
          onDrag: (dx) => setState(
            () => _sidebarWidth = (_sidebarWidth + dx).clamp(180.0, 600.0),
          ),
          onDragEnd: () => widget.repo.kvSet(
              'pref.sidebarWidth', _sidebarWidth.toStringAsFixed(1)),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: selected == null
                ? const _EmptyEditor(key: ValueKey('empty'))
                : NoteEditor(
                    key: ValueKey(selected),
                    repo: widget.repo,
                    noteId: selected,
                    onEdited: widget.sync.nudge,
                    onDeleted: () => setState(() => _selectedId = null),
                    autoFocus: _isNewNote,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _desktopTabs(List<NoteRow> notes) {
    final selected = notes.any((n) => n.id == _selectedId) ? _selectedId : null;
    return Column(
      children: [
        Container(
          height: 46,
          color: NotallyColors.surface,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.view_sidebar_outlined),
                tooltip: 'Switch to sidebar layout',
                color: NotallyColors.textFaint,
                iconSize: 20,
                onPressed: () {
                  setState(() => _layout = _DesktopLayout.sidebar);
                  widget.repo.kvSet('pref.layout', 'sidebar');
                },
              ),
              Container(width: 1, color: NotallyColors.border),
              Expanded(
                child: notes.isEmpty
                    ? const SizedBox()
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: notes
                              .map((n) => _NoteTab(
                                    note: n,
                                    selected: n.id == selected,
                                    onTap: () => setState(() {
                                      _selectedId = n.id;
                                      _isNewNote = false;
                                    }),
                                    onSecondaryTap: (pos) =>
                                        _showDesktopContextMenu(
                                            context, n, pos),
                                  ))
                              .toList(),
                        ),
                      ),
              ),
              Container(width: 1, color: NotallyColors.border),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'New note',
                color: NotallyColors.accent,
                iconSize: 20,
                onPressed: _newNote,
              ),
              _TrashButton(repo: widget.repo, onChanged: widget.sync.nudge),
              _RefreshButton(sync: widget.sync),
              _SyncButton(sync: widget.sync),
            ],
          ),
        ),
        Container(height: 1, color: NotallyColors.border),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: selected == null
                ? const _EmptyEditor(key: ValueKey('empty'))
                : NoteEditor(
                    key: ValueKey(selected),
                    repo: widget.repo,
                    noteId: selected,
                    onEdited: widget.sync.nudge,
                    onDeleted: () => setState(() => _selectedId = null),
                    autoFocus: _isNewNote,
                  ),
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
                      key: ValueKey(notes[i].id),
                      note: notes[i],
                      onTap: () => _openMobile(notes[i].id),
                      onLongPress: () => _showMobileNoteActions(notes[i]),
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
      _fadeSlideRoute(NoteEditorPage(
        repo: widget.repo,
        noteId: id,
        onEdited: widget.sync.nudge,
      )),
    );
  }

  // ---- Note context actions ------------------------------------------------

  Future<void> _showMobileNoteActions(NoteRow note) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: NotallyColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: NotallyColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(
                note.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: NotallyColors.textFaint,
              ),
              title: Text(
                note.pinned ? 'Unpin' : 'Pin',
                style: const TextStyle(color: NotallyColors.textPrimary),
              ),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await widget.repo.updateContent(note.id, pinned: !note.pinned);
                widget.sync.nudge();
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.colorize, color: NotallyColors.textFaint),
              title: const Text('Change color',
                  style: TextStyle(color: NotallyColors.textPrimary)),
              onTap: () async {
                Navigator.pop(sheetCtx);
                if (!mounted) return;
                final hex = await showDialog<String>(
                  context: context,
                  builder: (_) =>
                      NoteColorPickerDialog(current: note.color),
                );
                if (hex != null) {
                  await widget.repo.updateContent(note.id, color: hex);
                  widget.sync.nudge();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: NotallyColors.textFaint),
              title: const Text('Move to trash',
                  style: TextStyle(color: NotallyColors.textPrimary)),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await widget.repo.deleteNote(note.id);
                widget.sync.nudge();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showDesktopContextMenu(
      BuildContext context, NoteRow note, Offset position) async {
    final result = await showMenu<_NoteAction>(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx + 1, position.dy + 1),
      items: [
        PopupMenuItem(
          value: _NoteAction.pin,
          child: _MenuRow(
            icon: note.pinned ? Icons.push_pin : Icons.push_pin_outlined,
            label: note.pinned ? 'Unpin' : 'Pin',
          ),
        ),
        const PopupMenuItem(
          value: _NoteAction.color,
          child: _MenuRow(icon: Icons.colorize, label: 'Change color'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _NoteAction.trash,
          child: _MenuRow(icon: Icons.delete_outline, label: 'Move to trash'),
        ),
      ],
    );

    switch (result) {
      case _NoteAction.pin:
        await widget.repo.updateContent(note.id, pinned: !note.pinned);
        widget.sync.nudge();
      case _NoteAction.color:
        if (!context.mounted) return;
        final hex = await showDialog<String>(
          context: context,
          builder: (_) => NoteColorPickerDialog(current: note.color),
        );
        if (hex != null) {
          await widget.repo.updateContent(note.id, color: hex);
          widget.sync.nudge();
        }
      case _NoteAction.trash:
        await widget.repo.deleteNote(note.id);
        widget.sync.nudge();
        if (_selectedId == note.id) setState(() => _selectedId = null);
      case null:
        break;
    }
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
    required this.onLayoutToggle,
    this.onNoteContextMenu,
  });

  final List<NoteRow> notes;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onNew;
  final NotesRepository repo;
  final SyncService sync;
  final VoidCallback onLayoutToggle;
  final void Function(NoteRow, Offset)? onNoteContextMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: NotallyColors.surface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: NotallyColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Notes',
                          style: TextStyle(
                              color: NotallyColors.textBright,
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.view_headline_outlined),
                      tooltip: 'Switch to tabs layout',
                      color: NotallyColors.textFaint,
                      iconSize: 20,
                      onPressed: onLayoutToggle,
                    ),
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
                        onSecondaryTap: onNoteContextMenu == null
                            ? null
                            : (pos) => onNoteContextMenu!(n, pos),
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
  const _NoteListItem({
    required this.note,
    required this.active,
    required this.onTap,
    this.onSecondaryTap,
  });

  final NoteRow note;
  final bool active;
  final VoidCallback onTap;
  final void Function(Offset)? onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onSecondaryTapUp: onSecondaryTap == null
            ? null
            : (d) => onSecondaryTap!(d.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: colorFromHex(note.color),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                color: active ? NotallyColors.accent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              hoverColor: Colors.white10,
              child: Padding(
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
      ),
    ),
  );
  }
}

// --- Desktop tabs layout ----------------------------------------------------

class _NoteTab extends StatelessWidget {
  const _NoteTab({
    required this.note,
    required this.selected,
    required this.onTap,
    this.onSecondaryTap,
  });

  final NoteRow note;
  final bool selected;
  final VoidCallback onTap;
  final void Function(Offset)? onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapUp: onSecondaryTap == null
          ? null
          : (d) => onSecondaryTap!(d.globalPosition),
      child: InkWell(
        onTap: onTap,
        hoverColor: Colors.white10,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? NotallyColors.accent : Colors.transparent,
                width: 2,
              ),
              right: const BorderSide(color: NotallyColors.border),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (note.pinned)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.push_pin,
                      size: 11, color: NotallyColors.accent),
                ),
              Flexible(
                child: Text(
                  note.title.isEmpty ? 'Untitled' : note.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? NotallyColors.textBright
                        : NotallyColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Mobile card ------------------------------------------------------------

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.onLongPress,
  });

  final NoteRow note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: colorFromHex(note.color),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          onLongPress: onLongPress,
          splashColor: Colors.white24,
          highlightColor: Colors.white12,
          child: Padding(
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
      ),
    );
  }
}

// --- Shared bits ------------------------------------------------------------

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: NotallyColors.textFaint),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}

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

/// Manual "pull now" button.
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

/// Sync status icon with conflict badge.
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
  const _ResizeHandle({required this.onDrag, this.onDragEnd});
  final ValueChanged<double> onDrag;
  final VoidCallback? onDragEnd;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
        onHorizontalDragEnd: (_) => onDragEnd?.call(),
        child: Container(width: 6, color: NotallyColors.border),
      ),
    );
  }
}

class _EmptyEditor extends StatelessWidget {
  const _EmptyEditor({super.key});
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
              style: TextStyle(color: NotallyColors.textMuted, fontSize: 17)),
          SizedBox(height: 6),
          Text('Tap "New note" to get started.',
              style: TextStyle(color: NotallyColors.textFaint, fontSize: 14)),
        ],
      ),
    );
  }
}

String _previewOrPlaceholder(String body) {
  final p = previewText(body);
  return p.isEmpty ? 'No additional text' : p;
}

/// Subtle slide-up + fade transition used for the mobile note-editor route.
Route<void> _fadeSlideRoute(Widget page) => PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.10),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 270),
      reverseTransitionDuration: const Duration(milliseconds: 200),
    );
