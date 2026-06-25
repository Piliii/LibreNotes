import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../data/database.dart';
import '../data/notes_repository.dart';
import '../theme.dart';

/// The editing surface (title + markdown body) with ~500 ms debounced autosave.
/// A toolbar toggle flips the body between editing and a rendered markdown
/// preview; a pin toggle controls sort order.
class NoteEditor extends StatefulWidget {
  const NoteEditor({
    super.key,
    required this.repo,
    required this.noteId,
    this.onDeleted,
    this.onEdited,
  });

  final NotesRepository repo;
  final String noteId;
  final VoidCallback? onDeleted;

  /// Called after a real local edit is persisted, so sync can push promptly
  /// instead of waiting for the next poll.
  final VoidCallback? onEdited;

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  StreamSubscription<NoteRow?>? _sub;
  Timer? _debounce;
  bool _loading = true;
  bool _preview = false;
  bool _pinned = false;
  // Guards the controller listeners while we apply incoming (remote) content,
  // so adopting a synced change doesn't look like a local edit.
  bool _applying = false;
  // The last values we persisted. We only write when the controllers actually
  // diverge from these, so merely opening/closing a note never marks it dirty
  // or bumps its updatedAt (which would corrupt sort order and spawn phantom
  // conflicts).
  String _savedTitle = '';
  String _savedBody = '';
  NoteRow? _note;

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(_onChanged);
    _bodyCtrl.addListener(_onChanged);
    _subscribe();
  }

  @override
  void didUpdateWidget(NoteEditor old) {
    super.didUpdateWidget(old);
    if (old.noteId != widget.noteId) {
      // Persist any pending edits to the note we're leaving before rebinding.
      if (!_loading &&
          (_titleCtrl.text != _savedTitle || _bodyCtrl.text != _savedBody)) {
        widget.repo.updateContent(
          old.noteId,
          title: _titleCtrl.text,
          body: _bodyCtrl.text,
        );
        widget.onEdited?.call();
      }
      _debounce?.cancel();
      _preview = false;
      _subscribe();
    }
  }

  /// Watches the note so edits synced in from another device show up live
  /// instead of being masked (and then overwritten) by a stale snapshot.
  void _subscribe() {
    _sub?.cancel();
    _loading = true;
    _sub = widget.repo.watchNote(widget.noteId).listen(_onRow);
  }

  void _onRow(NoteRow? note) {
    if (!mounted) return;
    if (note == null || note.deleted) {
      if (!_loading) widget.onDeleted?.call();
      return;
    }
    // Don't clobber in-progress typing; only adopt remote content when the
    // editor has no unsaved local edits.
    final hasLocalEdits = !_loading &&
        (_titleCtrl.text != _savedTitle || _bodyCtrl.text != _savedBody);
    setState(() {
      _note = note;
      _pinned = note.pinned;
      if (!hasLocalEdits) {
        _applying = true;
        if (_titleCtrl.text != note.title) _titleCtrl.text = note.title;
        if (_bodyCtrl.text != note.body) _bodyCtrl.text = note.body;
        _applying = false;
        _savedTitle = note.title;
        _savedBody = note.body;
      }
      _loading = false;
    });
  }

  void _onChanged() {
    if (_loading || _applying) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _flush);
  }

  Future<void> _flush() async {
    _debounce?.cancel();
    if (_loading) return;
    if (_titleCtrl.text == _savedTitle && _bodyCtrl.text == _savedBody) return;
    _savedTitle = _titleCtrl.text;
    _savedBody = _bodyCtrl.text;
    await widget.repo.updateContent(
      widget.noteId,
      title: _savedTitle,
      body: _savedBody,
    );
    widget.onEdited?.call();
  }

  Future<void> _togglePin() async {
    final next = !_pinned;
    setState(() => _pinned = next);
    await widget.repo.updateContent(widget.noteId, pinned: next);
    widget.onEdited?.call();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NotallyColors.surface,
        title: const Text('Move to trash?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: NotallyColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Move to trash',
                style: TextStyle(color: NotallyColors.accent)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    _debounce?.cancel();
    _loading = true;
    await widget.repo.deleteNote(widget.noteId);
    widget.onEdited?.call();
    widget.onDeleted?.call();
  }

  @override
  void dispose() {
    _flush();
    _sub?.cancel();
    _debounce?.cancel();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: NotallyColors.accent),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 16, 30, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _toolbar(),
          const SizedBox(height: 4),
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(
              color: NotallyColors.textBright,
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: 'Title',
              hintStyle: TextStyle(color: NotallyColors.textFaint),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _preview ? _previewBody() : _editBody()),
        ],
      ),
    );
  }

  Widget _toolbar() {
    return Row(
      children: [
        Expanded(
          child: Text(
            _note == null ? 'New note' : 'Edited ${relative(_note!.updatedAt)}',
            style: const TextStyle(
                color: NotallyColors.textFaint, fontSize: 13),
          ),
        ),
        _ToolButton(
          icon: _pinned ? Icons.push_pin : Icons.push_pin_outlined,
          tooltip: _pinned ? 'Unpin' : 'Pin',
          active: _pinned,
          onTap: _togglePin,
        ),
        _ToolButton(
          icon: _preview ? Icons.edit_outlined : Icons.visibility_outlined,
          tooltip: _preview ? 'Edit' : 'Preview',
          active: _preview,
          onTap: () => setState(() => _preview = !_preview),
        ),
        _ToolButton(
          icon: Icons.delete_outline,
          tooltip: 'Move to trash',
          onTap: _delete,
        ),
      ],
    );
  }

  Widget _editBody() {
    return TextField(
      controller: _bodyCtrl,
      expands: true,
      maxLines: null,
      textAlignVertical: TextAlignVertical.top,
      style: const TextStyle(
          color: NotallyColors.textPrimary, fontSize: 16, height: 1.5),
      decoration: const InputDecoration(
        border: InputBorder.none,
        hintText: 'Start typing… markdown supported',
        hintStyle: TextStyle(color: NotallyColors.textFaint),
      ),
    );
  }

  Widget _previewBody() {
    final text = _bodyCtrl.text.trim();
    if (text.isEmpty) {
      return const Align(
        alignment: Alignment.topLeft,
        child: Text('Nothing to preview yet.',
            style: TextStyle(color: NotallyColors.textFaint, fontSize: 15)),
      );
    }
    return Markdown(
      data: text,
      padding: EdgeInsets.zero,
      styleSheet: notallyMarkdownStyle(),
    );
  }

  static String relative(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      iconSize: 20,
      color: active ? NotallyColors.accent : NotallyColors.textFaint,
      icon: Icon(icon),
    );
  }
}

/// Full-screen editor for the mobile layout.
class NoteEditorPage extends StatelessWidget {
  const NoteEditorPage({
    super.key,
    required this.repo,
    required this.noteId,
    this.onEdited,
  });

  final NotesRepository repo;
  final String noteId;
  final VoidCallback? onEdited;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NotallyColors.background,
      appBar: AppBar(
        backgroundColor: NotallyColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: NotallyColors.textPrimary),
      ),
      body: SafeArea(
        child: NoteEditor(
          repo: repo,
          noteId: noteId,
          onEdited: onEdited,
          onDeleted: () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }
}
