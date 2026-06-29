import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/database.dart';
import '../data/notes_repository.dart';
import '../format.dart';
import '../sync/sync_service.dart';
import '../theme.dart';
import 'archive_page.dart';
import 'note_editor.dart';
import 'sync_settings_page.dart';

enum _DesktopLayout { sidebar, tabs }

enum _NoteAction { pin, color, archive }

enum _BulkAction { archive, pin, unpin }

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
  String _searchQuery = '';
  late final TextEditingController _searchController;
  bool _mobileSearchActive = false;
  Set<String> _selectedIds = {};
  String? _lastSelectedId;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadPrefs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.sizeOf(context).width >= _desktopBreakpoint) _newNote();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      _selectedIds = {};
      _selectedId = id;
      _isNewNote = true;
    });
  }

  void _handleNoteSelect(String id, List<NoteRow> orderedNotes) {
    final ctrl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;

    if (shift && _lastSelectedId != null) {
      final i1 = orderedNotes.indexWhere((n) => n.id == _lastSelectedId);
      final i2 = orderedNotes.indexWhere((n) => n.id == id);
      if (i1 != -1 && i2 != -1) {
        final from = i1 < i2 ? i1 : i2;
        final to = i1 < i2 ? i2 : i1;
        setState(() {
          _selectedIds =
              orderedNotes.sublist(from, to + 1).map((n) => n.id).toSet();
        });
      }
      return;
    }

    if (ctrl) {
      setState(() {
        final ids = Set<String>.from(_selectedIds);
        if (ids.contains(id)) {
          ids.remove(id);
        } else {
          ids.add(id);
          _selectedId = id;
          _isNewNote = false;
        }
        _selectedIds = ids;
        _lastSelectedId = id;
      });
      return;
    }

    setState(() {
      _selectedIds = {};
      _selectedId = id;
      _lastSelectedId = id;
      _isNewNote = false;
    });
  }

  Future<void> _handleBulkAction(Set<String> ids, _BulkAction action) async {
    switch (action) {
      case _BulkAction.archive:
        for (final id in ids) {
          await widget.repo.archiveNote(id);
        }
        if (ids.contains(_selectedId)) setState(() => _selectedId = null);
        widget.sync.nudge();
      case _BulkAction.pin:
        for (final id in ids) {
          await widget.repo.updateContent(id, pinned: true);
        }
        widget.sync.nudge();
      case _BulkAction.unpin:
        for (final id in ids) {
          await widget.repo.updateContent(id, pinned: false);
        }
        widget.sync.nudge();
    }
    setState(() => _selectedIds = {});
  }

  List<NoteRow> _filtered(List<NoteRow> notes) {
    if (_searchQuery.isEmpty) return notes;
    final q = _searchQuery.toLowerCase();
    return notes
        .where((n) =>
            n.title.toLowerCase().contains(q) ||
            n.body.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<NoteRow>>(
        stream: widget.repo.watchNotes(),
        builder: (context, snapshot) {
          final allNotes = snapshot.data ?? const <NoteRow>[];
          final displayed = _filtered(allNotes);
          final isDesktop =
              MediaQuery.sizeOf(context).width >= _desktopBreakpoint;
          return isDesktop
              ? _desktop(allNotes, displayed)
              : _mobile(displayed, allNotes.length);
        },
      ),
    );
  }

  // ---- Desktop -------------------------------------------------------------

  Widget _desktop(List<NoteRow> allNotes, List<NoteRow> filteredNotes) {
    final child = switch (_layout) {
      _DesktopLayout.sidebar => _desktopSidebar(filteredNotes),
      _DesktopLayout.tabs => _desktopTabs(allNotes),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: KeyedSubtree(key: ValueKey(_layout), child: child),
    );
  }

  Widget _desktopSidebar(List<NoteRow> notes) {
    final selected = notes.any((n) => n.id == _selectedId) ? _selectedId : null;
    final multiCount = _selectedIds.length;
    return Row(
      children: [
        SizedBox(
          width: _sidebarWidth,
          child: _Sidebar(
            notes: notes,
            selectedId: selected,
            selectedIds: _selectedIds,
            onSelect: (id) => _handleNoteSelect(id, notes),
            onBulkAction: _handleBulkAction,
            onNew: _newNote,
            repo: widget.repo,
            sync: widget.sync,
            onLayoutToggle: () {
              setState(() => _layout = _DesktopLayout.tabs);
              widget.repo.kvSet('pref.layout', 'tabs');
            },
            onNoteContextMenu: (note, pos) =>
                _showDesktopContextMenu(context, note, pos),
            searchController: _searchController,
            onSearchChanged: (q) => setState(() => _searchQuery = q),
            hasQuery: _searchQuery.isNotEmpty,
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
            child: multiCount > 1
                ? _MultiSelectPanel(
                    key: ValueKey('multi-$multiCount'),
                    count: multiCount,
                    onDelete: () =>
                        _handleBulkAction(_selectedIds, _BulkAction.archive),
                    onPin: () =>
                        _handleBulkAction(_selectedIds, _BulkAction.pin),
                    onUnpin: () =>
                        _handleBulkAction(_selectedIds, _BulkAction.unpin),
                  )
                : selected == null
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
              _ArchiveButton(repo: widget.repo, onChanged: widget.sync.nudge),
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

  Widget _mobile(List<NoteRow> notes, int totalCount) {
    final pinned = notes.where((n) => n.pinned).toList();
    final unpinned = notes.where((n) => !n.pinned).toList();
    final hasSections =
        pinned.isNotEmpty && unpinned.isNotEmpty && _searchQuery.isEmpty;

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
        child: RefreshIndicator(
          color: NotallyColors.accent,
          backgroundColor: NotallyColors.surface,
          onRefresh: widget.sync.syncNow,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, -0.3),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                            parent: animation, curve: Curves.easeOut)),
                        child: child,
                      ),
                    ),
                    child: _mobileSearchActive
                        ? Row(
                            key: const ValueKey('search'),
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back),
                                color: NotallyColors.textFaint,
                                iconSize: 22,
                                padding: EdgeInsets.zero,
                                onPressed: () => setState(() {
                                  _mobileSearchActive = false;
                                  _searchQuery = '';
                                  _searchController.clear();
                                }),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  autofocus: true,
                                  onChanged: (q) =>
                                      setState(() => _searchQuery = q),
                                  style: const TextStyle(
                                      color: NotallyColors.textPrimary,
                                      fontSize: 22),
                                  decoration: const InputDecoration(
                                    hintText: 'Search notes…',
                                    hintStyle: TextStyle(
                                        color: NotallyColors.textFaint,
                                        fontSize: 22),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                              if (_searchQuery.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  color: NotallyColors.textFaint,
                                  iconSize: 20,
                                  padding: EdgeInsets.zero,
                                  onPressed: () => setState(() {
                                    _searchQuery = '';
                                    _searchController.clear();
                                  }),
                                ),
                            ],
                          )
                        : Row(
                            key: const ValueKey('title'),
                            children: [
                              Expanded(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
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
                                    if (totalCount > 0)
                                      Text(
                                        '$totalCount',
                                        style: const TextStyle(
                                            color: NotallyColors.textFaint,
                                            fontSize: 18),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.search),
                                tooltip: 'Search',
                                color: NotallyColors.textFaint,
                                iconSize: 22,
                                onPressed: () =>
                                    setState(() => _mobileSearchActive = true),
                              ),
                              _ArchiveButton(
                                  repo: widget.repo,
                                  onChanged: widget.sync.nudge),
                              _RefreshButton(sync: widget.sync),
                              _SyncButton(sync: widget.sync),
                            ],
                          ),
                  ),
                ),
              ),
              if (notes.isEmpty && _searchQuery.isNotEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off,
                            size: 52, color: NotallyColors.textFaint),
                        const SizedBox(height: 16),
                        Text(
                          'No notes match "$_searchQuery"',
                          style: const TextStyle(
                              color: NotallyColors.textMuted, fontSize: 15),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else if (notes.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyHint(),
                )
              else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasSections) ...[
                          const _SectionLabel('Pinned'),
                          const SizedBox(height: 8),
                          _masonryGrid(pinned),
                          const SizedBox(height: 4),
                          const _SectionLabel('Notes'),
                          const SizedBox(height: 8),
                          _masonryGrid(unpinned),
                        ] else
                          _masonryGrid(notes),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _masonryGrid(List<NoteRow> notes) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 14) / 2;
        final left = [for (var i = 0; i < notes.length; i += 2) notes[i]];
        final right = [for (var i = 1; i < notes.length; i += 2) notes[i]];

        Widget column(List<NoteRow> items) => SizedBox(
              width: cardWidth,
              child: Column(
                children: [
                  for (final note in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Dismissible(
                        key: ValueKey('d-${note.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A4A3A),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.archive_outlined,
                              color: Colors.white70, size: 26),
                        ),
                        onDismissed: (_) async {
                          await widget.repo.archiveNote(note.id);
                          widget.sync.nudge();
                        },
                        child: _NoteCard(
                          note: note,
                          onTap: () => _openMobile(note.id),
                          onLongPress: () => _showMobileNoteActions(note),
                        ),
                      ),
                    ),
                ],
              ),
            );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            column(left),
            const SizedBox(width: 14),
            column(right),
          ],
        );
      },
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
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      isScrollControlled: true,
      builder: (sheetCtx) => ClipRRect(
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: NotallyColors.surface.withValues(alpha: 0.88),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1), width: 0.5),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // drag handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // note title context
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Text(
                      note.title.isEmpty ? 'Untitled' : note.title,
                      style: const TextStyle(
                        color: NotallyColors.textBright,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Divider(
                      color: Colors.white.withValues(alpha: 0.07), height: 1),
                  // inline color picker
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: kNoteColorHexes.map((hex) {
                        final color = colorFromHex(hex);
                        final selected = note.color == hex;
                        return GestureDetector(
                          onTap: () async {
                            Navigator.pop(sheetCtx);
                            await widget.repo
                                .updateContent(note.id, color: hex);
                            widget.sync.nudge();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: selected ? 34 : 30,
                            height: selected ? 34 : 30,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? NotallyColors.accent
                                    : Colors.white24,
                                width: selected ? 2.5 : 1,
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: NotallyColors.accent
                                            .withValues(alpha: 0.45),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: selected
                                ? const Icon(Icons.check,
                                    size: 15, color: Colors.white70)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  Divider(
                      color: Colors.white.withValues(alpha: 0.07), height: 1),
                  ListTile(
                    leading: Icon(
                      note.pinned
                          ? Icons.push_pin
                          : Icons.push_pin_outlined,
                      color: NotallyColors.textFaint,
                    ),
                    title: Text(
                      note.pinned ? 'Unpin' : 'Pin',
                      style: const TextStyle(
                          color: NotallyColors.textPrimary),
                    ),
                    onTap: () async {
                      Navigator.pop(sheetCtx);
                      await widget.repo
                          .updateContent(note.id, pinned: !note.pinned);
                      widget.sync.nudge();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.archive_outlined,
                        color: NotallyColors.textFaint),
                    title: const Text('Archive',
                        style:
                            TextStyle(color: NotallyColors.textPrimary)),
                    onTap: () async {
                      Navigator.pop(sheetCtx);
                      await widget.repo.archiveNote(note.id);
                      widget.sync.nudge();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline,
                        color: NotallyColors.textFaint),
                    title: const Text('Move to Trash',
                        style:
                            TextStyle(color: NotallyColors.textPrimary)),
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
          ),
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
          value: _NoteAction.archive,
          child: _MenuRow(icon: Icons.archive_outlined, label: 'Archive'),
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
      case _NoteAction.archive:
        await widget.repo.archiveNote(note.id);
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
    required this.selectedIds,
    required this.onSelect,
    required this.onBulkAction,
    required this.onNew,
    required this.repo,
    required this.sync,
    required this.onLayoutToggle,
    this.onNoteContextMenu,
    required this.searchController,
    required this.onSearchChanged,
    required this.hasQuery,
  });

  final List<NoteRow> notes;
  final String? selectedId;
  final Set<String> selectedIds;
  final ValueChanged<String> onSelect;
  final void Function(Set<String>, _BulkAction) onBulkAction;
  final VoidCallback onNew;
  final NotesRepository repo;
  final SyncService sync;
  final VoidCallback onLayoutToggle;
  final void Function(NoteRow, Offset)? onNoteContextMenu;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final bool hasQuery;

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
                    _ArchiveButton(repo: repo, onChanged: sync.nudge),
                    _RefreshButton(sync: sync),
                    _SyncButton(sync: sync),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  style: const TextStyle(
                      color: NotallyColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search notes…',
                    hintStyle: const TextStyle(
                        color: NotallyColors.textFaint, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_outlined,
                        size: 18, color: NotallyColors.textFaint),
                    suffixIcon: hasQuery
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            color: NotallyColors.textFaint,
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              searchController.clear();
                              onSearchChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: NotallyColors.background,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: NotallyColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: NotallyColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: NotallyColors.accent, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
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
            child: Column(
              children: [
                Expanded(
                  child: notes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                hasQuery
                                    ? Icons.search_off
                                    : Icons.note_add_outlined,
                                size: 36,
                                color: NotallyColors.textFaint
                                    .withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                hasQuery ? 'No notes match' : 'No notes yet',
                                style: const TextStyle(
                                    color: NotallyColors.textFaint,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : _buildNoteList(
                          notes,
                          selectedId,
                          onSelect,
                          onNoteContextMenu,
                          hasQuery,
                          selectedIds,
                        ),
                ),
                if (selectedIds.length > 1)
                  _BulkActionBar(
                    count: selectedIds.length,
                    onAction: (a) => onBulkAction(selectedIds, a),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildNoteList(
  List<NoteRow> notes,
  String? selectedId,
  ValueChanged<String> onSelect,
  void Function(NoteRow, Offset)? onNoteContextMenu,
  bool hasQuery,
  Set<String> selectedIds,
) {
  final pinned = notes.where((n) => n.pinned).toList();
  final unpinned = notes.where((n) => !n.pinned).toList();
  final hasSections = !hasQuery && pinned.isNotEmpty && unpinned.isNotEmpty;

  Widget item(NoteRow n) => _NoteListItem(
        note: n,
        active: n.id == selectedId,
        isMultiSelected: selectedIds.contains(n.id),
        onTap: () => onSelect(n.id),
        onSecondaryTap: onNoteContextMenu == null
            ? null
            : (pos) => onNoteContextMenu(n, pos),
      );

  return ScrollbarTheme(
    data: ScrollbarThemeData(
      thickness: WidgetStateProperty.all(3),
      radius: const Radius.circular(3),
      thumbColor: WidgetStateProperty.all(
        NotallyColors.textFaint.withValues(alpha: 0.35),
      ),
    ),
    child: ListView(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      children: [
        if (hasSections) ...[
          _SidebarSectionLabel('Pinned'),
          ...pinned.map(item),
          const SizedBox(height: 4),
          _SidebarSectionLabel('Notes'),
          ...unpinned.map(item),
        ] else
          ...notes.map(item),
      ],
    ),
  );
}

class _SidebarSectionLabel extends StatelessWidget {
  const _SidebarSectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: NotallyColors.textFaint,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _NoteListItem extends StatelessWidget {
  const _NoteListItem({
    required this.note,
    required this.active,
    required this.isMultiSelected,
    required this.onTap,
    this.onSecondaryTap,
  });

  final NoteRow note;
  final bool active;
  final bool isMultiSelected;
  final VoidCallback onTap;
  final void Function(Offset)? onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    final rawBase = colorFromHex(note.color);
    final base = isMultiSelected
        ? Color.lerp(rawBase, NotallyColors.accent, 0.12)!
        : rawBase;
    final lighter = Color.lerp(base, Colors.white, 0.06)!;
    final darker = Color.lerp(base, Colors.black, 0.08)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onSecondaryTapUp: onSecondaryTap == null
            ? null
            : (d) => onSecondaryTap!(d.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [lighter, base, darker],
              stops: const [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                color: (active || isMultiSelected)
                    ? NotallyColors.accent
                        .withValues(alpha: active ? 1.0 : 0.65)
                    : Colors.transparent,
                width: 3,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                spreadRadius: -2,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                hoverColor: Colors.white.withValues(alpha: 0.06),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 20, 12, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isMultiSelected)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(
                                Icons.check_circle,
                                size: 13,
                                color: NotallyColors.accent
                                    .withValues(alpha: 0.9),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              note.title.isNotEmpty
                                  ? note.title
                                  : _previewOrPlaceholder(note.body),
                              maxLines: note.title.isEmpty ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: active
                                    ? NotallyColors.textBright
                                    : NotallyColors.textBright
                                        .withValues(alpha: 0.92),
                                fontSize: 14,
                                fontWeight: active
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (note.pinned)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Icon(Icons.push_pin,
                                  size: 12,
                                  color: NotallyColors.accent
                                      .withValues(alpha: 0.8)),
                            ),
                        ],
                      ),
                      if (note.title.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          _previewOrPlaceholder(note.body),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: NotallyColors.textMuted
                                  .withValues(alpha: 0.85),
                              fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Bulk selection UI ------------------------------------------------------

class _BulkActionBar extends StatelessWidget {
  const _BulkActionBar({required this.count, required this.onAction});
  final int count;
  final void Function(_BulkAction) onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: NotallyColors.surface,
        border: const Border(top: BorderSide(color: NotallyColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            '$count selected',
            style: const TextStyle(
                color: NotallyColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.push_pin_outlined),
            tooltip: 'Pin selected',
            color: NotallyColors.textFaint,
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => onAction(_BulkAction.pin),
          ),
          IconButton(
            icon: const Icon(Icons.push_pin),
            tooltip: 'Unpin selected',
            color: NotallyColors.textFaint,
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => onAction(_BulkAction.unpin),
          ),
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'Archive selected',
            color: NotallyColors.accent,
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => onAction(_BulkAction.archive),
          ),
        ],
      ),
    );
  }
}

class _MultiSelectPanel extends StatelessWidget {
  const _MultiSelectPanel({
    super.key,
    required this.count,
    required this.onDelete,
    required this.onPin,
    required this.onUnpin,
  });

  final int count;
  final VoidCallback onDelete;
  final VoidCallback onPin;
  final VoidCallback onUnpin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  NotallyColors.accent.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
              border: Border.all(
                color: NotallyColors.accent.withValues(alpha: 0.20),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.checklist_rounded,
              size: 32,
              color: NotallyColors.accent.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '$count notes selected',
            style: const TextStyle(
                color: NotallyColors.textMuted,
                fontSize: 16,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          const Text(
            'Use the sidebar bar below to act on them',
            style: TextStyle(color: NotallyColors.textFaint, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.push_pin_outlined, size: 16),
                label: const Text('Pin'),
                onPressed: onPin,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.push_pin, size: 16),
                label: const Text('Unpin'),
                onPressed: onUnpin,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.archive_outlined, size: 16),
                label: const Text('Archive'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: NotallyColors.accent,
                  side: BorderSide(
                      color: NotallyColors.accent.withValues(alpha: 0.5)),
                ),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
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
                  note.title.isNotEmpty
                      ? note.title
                      : previewText(note.body).isNotEmpty
                          ? previewText(note.body)
                          : 'Untitled',
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

class _NoteCard extends StatefulWidget {
  const _NoteCard({
    required this.note,
    required this.onTap,
    this.onLongPress,
  });

  final NoteRow note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enterCtrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _opacity = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));
    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = colorFromHex(widget.note.color);
    final lighter = Color.lerp(base, Colors.white, 0.07)!;
    final darker = Color.lerp(base, Colors.black, 0.10)!;

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      constraints: const BoxConstraints(minHeight: 100),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.45, 1.0],
          colors: [lighter, base, darker],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.09),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.38),
            blurRadius: 14,
            spreadRadius: -2,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: base.withValues(alpha: 0.30),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            splashColor: Colors.white24,
            highlightColor: Colors.white10,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.note.title.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            widget.note.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: NotallyColors.textBright,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                height: 1.3),
                          ),
                        ),
                        if (widget.note.pinned)
                          Padding(
                            padding: const EdgeInsets.only(left: 6, top: 2),
                            child: Icon(Icons.push_pin,
                                size: 13,
                                color: NotallyColors.accent
                                    .withValues(alpha: 0.85)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ] else if (widget.note.pinned)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Icon(Icons.push_pin,
                            size: 13,
                            color:
                                NotallyColors.accent.withValues(alpha: 0.85)),
                      ),
                    ),
                  Text(
                    _previewOrPlaceholder(widget.note.body),
                    maxLines: widget.note.title.isEmpty ? 9 : 7,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: NotallyColors.textMuted.withValues(alpha: 0.9),
                        fontSize: 13,
                        height: 1.45),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    relativeTime(widget.note.updatedAt),
                    style: TextStyle(
                        color: NotallyColors.textFaint.withValues(alpha: 0.75),
                        fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
        ),
      ),
    );
  }
}

// --- Section header ---------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: NotallyColors.textFaint,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
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

/// Opens the archive screen. Trash is accessible from inside the archive page.
class _ArchiveButton extends StatelessWidget {
  const _ArchiveButton({required this.repo, this.onChanged});

  final NotesRepository repo;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Archive',
      color: NotallyColors.textFaint,
      iconSize: 22,
      icon: const Icon(Icons.archive_outlined),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ArchivePage(repo: repo, onChanged: onChanged),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  NotallyColors.accent.withValues(alpha: 0.18),
                  Colors.transparent,
                ],
              ),
              border: Border.all(
                color: NotallyColors.accent.withValues(alpha: 0.20),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.article_outlined,
              size: 32,
              color: NotallyColors.accent.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Select a note',
            style: TextStyle(
                color: NotallyColors.textMuted,
                fontSize: 16,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 5),
          const Text(
            'or create a new one',
            style:
                TextStyle(color: NotallyColors.textFaint, fontSize: 13),
          ),
        ],
      ),
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
/// opaque:false keeps the previous route rendered during the fade so there
/// is no black flash at opacity=0.
Route<void> _fadeSlideRoute(Widget page) => PageRouteBuilder<void>(
      opaque: false,
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
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 220),
    );
