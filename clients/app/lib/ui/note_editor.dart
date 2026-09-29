import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart' hide colorFromHex;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/notes_repository.dart';
import '../markdown_editing_controller.dart';
import '../markdown_format.dart';
import '../markdown_highlight.dart';
import '../theme.dart';

/// The editing surface (title + markdown body) with ~500 ms debounced autosave.
/// A toolbar toggle flips the body between editing and a rendered markdown
/// preview.
class NoteEditor extends StatefulWidget {
  const NoteEditor({
    super.key,
    required this.repo,
    required this.noteId,
    this.onDeleted,
    this.onEdited,
    this.autoFocus = false,
  });

  final NotesRepository repo;
  final String noteId;
  final VoidCallback? onDeleted;

  /// Called after a real local edit is persisted, so sync can push promptly
  /// instead of waiting for the next poll.
  final VoidCallback? onEdited;

  /// If true, focuses the body text field once the note finishes loading.
  final bool autoFocus;

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = MarkdownEditingController();
  final _bodyFocus = FocusNode();
  StreamSubscription<NoteRow?>? _sub;
  Timer? _debounce;
  bool _loading = true;
  bool _preview = false;
  String _color = '#2a2a2a';
  int? _expiresAt;
  bool _applying = false;
  bool _didAutoFocus = false;
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
      _debounce?.cancel();
      if (!_loading) {
        if (_titleCtrl.text.isEmpty && _bodyCtrl.text.isEmpty) {
          // No text ever written — discard the note. Goes through the normal
          // tombstone path (not a raw purge) so that if sync already pushed
          // this note to the server, the delete propagates instead of
          // silently orphaning it there to be resurrected on the next pull.
          widget.repo.deleteNote(old.noteId);
        } else if (_titleCtrl.text != _savedTitle ||
            _bodyCtrl.text != _savedBody) {
          widget.repo.updateContent(
            old.noteId,
            title: _titleCtrl.text,
            body: _bodyCtrl.text,
          );
          widget.onEdited?.call();
        }
      }
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
    final wasLoading = _loading;
    final hasLocalEdits = !_loading &&
        (_titleCtrl.text != _savedTitle || _bodyCtrl.text != _savedBody);
    setState(() {
      _note = note;
      _color = note.color;
      _expiresAt = note.expiresAt;
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
    if (wasLoading && widget.autoFocus && !_didAutoFocus) {
      _didAutoFocus = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _bodyFocus.requestFocus();
      });
    }
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

  Future<void> _pickColor() async {
    final hex = await showDialog<String>(
      context: context,
      builder: (_) => NoteColorPickerDialog(current: _color),
    );
    if (hex == null || hex == _color) return;
    setState(() => _color = hex);
    await widget.repo.updateContent(widget.noteId, color: hex);
    widget.onEdited?.call();
  }

  Future<void> _archive() async {
    _debounce?.cancel();
    _loading = true;
    await widget.repo.archiveNote(widget.noteId);
    widget.onEdited?.call();
    widget.onDeleted?.call();
  }

  Future<void> _trash() async {
    _debounce?.cancel();
    _loading = true;
    await widget.repo.deleteNote(widget.noteId);
    widget.onEdited?.call();
    widget.onDeleted?.call();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _sub?.cancel();
    _bodyFocus.dispose();
    if (!_loading && _titleCtrl.text.isEmpty && _bodyCtrl.text.isEmpty) {
      // No text ever written — discard the note. See didUpdateWidget above
      // for why this must be a tombstone (deleteNote), not a raw purge.
      widget.repo.deleteNote(widget.noteId);
    } else {
      _flush();
    }
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  /// Text tones guaranteed to stay readable against this note's own
  /// background color, however light/dark/custom/gradient it is.
  NoteTextColors get _textColors => NoteTextColors.forBackground(_color);

  @override
  Widget build(BuildContext context) {
    final textColors = _textColors;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: _loading
          ? const Center(
              key: ValueKey('loading'),
              child: CircularProgressIndicator(color: NotallyColors.accent),
            )
          : AnimatedContainer(
              key: const ValueKey('editor'),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
              decoration: noteBackgroundDecoration(_color),
              padding: const EdgeInsets.fromLTRB(30, 16, 30, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _toolbar(textColors),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _titleCtrl,
                    style: TextStyle(
                      color: textColors.bright,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Title',
                      hintStyle: TextStyle(color: textColors.faint),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _preview
                        ? _previewBody(textColors)
                        : _editBody(textColors),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _toolbar(NoteTextColors textColors) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _note == null
                ? 'New note'
                : _expiresAt != null
                    ? 'Self-destructs ${untilExpiry(_expiresAt!)}'
                    : 'Edited ${relative(_note!.updatedAt)}',
            style: TextStyle(
              color: _expiresAt != null
                  ? NotallyColors.accent
                  : textColors.faint,
              fontSize: 13,
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ToolButton(
                    icon: Icons.colorize,
                    tooltip: 'Note color',
                    onTap: _pickColor,
                    color: textColors.faint,
                  ),
                  _ToolButton(
                    icon: _preview ? Icons.edit_outlined : Icons.visibility_outlined,
                    tooltip: _preview ? 'Edit' : 'Preview',
                    active: _preview,
                    onTap: () => setState(() => _preview = !_preview),
                    color: textColors.faint,
                  ),
                  _ToolButton(
                    icon: Icons.archive_outlined,
                    tooltip: 'Archive',
                    onTap: _archive,
                    color: textColors.faint,
                  ),
                  _ToolButton(
                    icon: Icons.delete_outline,
                    tooltip: 'Move to Trash',
                    onTap: _trash,
                    color: textColors.faint,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _editBody(NoteTextColors textColors) {
    return TextField(
      controller: _bodyCtrl,
      focusNode: _bodyFocus,
      expands: true,
      maxLines: null,
      textAlignVertical: TextAlignVertical.top,
      style: TextStyle(color: textColors.primary, fontSize: 16, height: 1.5),
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: 'Start typing… markdown supported',
        hintStyle: TextStyle(color: textColors.faint),
      ),
      contextMenuBuilder: _bodyContextMenuBuilder,
    );
  }

  /// Adds formatting actions — Bold, Italic, Heading, Bullet list,
  /// Highlight/Remove highlight — to the native text selection toolbar (the
  /// same one that shows Cut/Copy/Paste). This is the "WYSIWYG mode": select
  /// text, get visual actions, they apply the equivalent Markdown under the
  /// hood — the body stays plain Markdown the whole time, this is just an
  /// alternative to typing the syntax by hand. It's the one hook that works
  /// for both a mouse drag-select on desktop and a long-press select on
  /// mobile, so one implementation covers both.
  Widget _bodyContextMenuBuilder(
      BuildContext context, EditableTextState editableTextState) {
    final value = editableTextState.textEditingValue;
    final selection = value.selection;
    final items = List<ContextMenuButtonItem>.of(
        editableTextState.contextMenuButtonItems);
    if (selection.isValid && !selection.isCollapsed) {
      final selectedText = selection.textInside(value.text);
      void dismissThen(VoidCallback action) {
        ContextMenuController.removeAny();
        action();
      }

      items.addAll([
        ContextMenuButtonItem(
          label: 'Bold',
          onPressed: () => dismissThen(() => _replaceSelection(
              selection, toggleBold(selectedText))),
        ),
        ContextMenuButtonItem(
          label: 'Italic',
          onPressed: () => dismissThen(() => _replaceSelection(
              selection, toggleItalic(selectedText))),
        ),
        ContextMenuButtonItem(
          label: 'Heading',
          onPressed: () => dismissThen(() => _pickHeading(selection)),
        ),
        ContextMenuButtonItem(
          label: 'Bullet list',
          onPressed: () => dismissThen(() => _bodyCtrl.value =
              toggleBulletList(_bodyCtrl.text, selection)),
        ),
      ]);
      final exact = matchExactHighlight(selectedText);
      items.add(ContextMenuButtonItem(
        label: exact != null ? 'Remove highlight' : 'Highlight',
        onPressed: () => dismissThen(() {
          if (exact != null) {
            _replaceSelection(selection, exact.inner);
          } else {
            _highlightSelection(selection);
          }
        }),
      ));
    }
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: items,
    );
  }

  void _replaceSelection(TextSelection selection, String replacement) {
    final text = _bodyCtrl.text;
    final newText = text.replaceRange(selection.start, selection.end, replacement);
    _bodyCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
          offset: selection.start + replacement.length),
    );
  }

  Future<void> _highlightSelection(TextSelection selection) async {
    final selected = selection.textInside(_bodyCtrl.text);
    final colorKey = await showDialog<String>(
      context: context,
      builder: (_) => const HighlightColorPickerDialog(),
    );
    if (colorKey == null || !mounted) return;
    _replaceSelection(selection, wrapHighlight(selected, colorKey));
  }

  Future<void> _pickHeading(TextSelection selection) async {
    final result = await showDialog<HeadingResult>(
      context: context,
      builder: (_) => const HeadingPickerDialog(),
    );
    if (result == null || !mounted) return;
    _bodyCtrl.value = applyHeading(_bodyCtrl.text, selection, result.level);
  }

  Widget _previewBody(NoteTextColors textColors) {
    final text = _bodyCtrl.text.trim();
    if (text.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: Text('Nothing to preview yet.',
            style: TextStyle(color: textColors.faint, fontSize: 15)),
      );
    }
    return Markdown(
      data: text,
      padding: EdgeInsets.zero,
      styleSheet: notallyMarkdownStyle(colors: textColors),
      inlineSyntaxes: [HighlightSyntax()],
      builders: {'mark': HighlightBuilder()},
      onTapLink: (_, href, __) async {
        if (href == null) return;
        final uri = Uri.tryParse(href);
        if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
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

  static String untilExpiry(int expiresAtMs) {
    final diff =
        DateTime.fromMillisecondsSinceEpoch(expiresAtMs).difference(DateTime.now());
    if (diff.isNegative) return 'soon';
    if (diff.inMinutes < 1) return 'in under a minute';
    if (diff.inMinutes < 60) return 'in ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'in ${diff.inHours}h';
    return 'in ${diff.inDays}d';
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.color,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      iconSize: 20,
      color: active ? NotallyColors.accent : color,
      icon: Icon(icon),
    );
  }
}

/// Full-screen editor for the mobile layout.
/// Streams the note's color so the scaffold background updates live when the
/// user changes it from the toolbar color picker.
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
    return StreamBuilder<NoteRow?>(
      stream: repo.watchNote(noteId),
      builder: (context, snap) {
        final color = snap.data?.color ?? '#2a2a2a';
        final bg = noteBackgroundDecoration(color);
        final textColors = NoteTextColors.forBackground(color);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          decoration: bg,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              iconTheme: IconThemeData(color: textColors.primary),
            ),
            body: SafeArea(
              child: NoteEditor(
                repo: repo,
                noteId: noteId,
                onEdited: onEdited,
                onDeleted: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class HighlightColorPickerDialog extends StatelessWidget {
  const HighlightColorPickerDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: NotallyColors.surface,
      title: const Text(
        'Highlight color',
        style: TextStyle(color: NotallyColors.textBright, fontSize: 16),
      ),
      content: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: kHighlightColors.entries.map((entry) {
          return GestureDetector(
            onTap: () => Navigator.pop(context, entry.key),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: entry.value,
                shape: BoxShape.circle,
                border: Border.all(color: NotallyColors.border, width: 1.5),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Lets the user pick a note color: a preset swatch, any custom hex color, or
/// (in Gradient mode) 2-3 hex stops. Pops the encoded color string (see
/// [isGradientColor]/[encodeGradient] in theme.dart) for the caller to save
/// as-is — `null` if dismissed without a choice.
///
/// In Solid mode, tapping a preset or confirming a custom hex pops
/// immediately (the fast, common path). Gradient mode needs several picks
/// (2-3 stops, each its own color) before there's a result to pop, so it
/// works against the same preset grid/hex field but applies each pick to
/// whichever stop is "active", and only pops on the explicit Apply button.
class NoteColorPickerDialog extends StatefulWidget {
  const NoteColorPickerDialog({super.key, required this.current});

  final String current;

  @override
  State<NoteColorPickerDialog> createState() => _NoteColorPickerDialogState();
}

class _NoteColorPickerDialogState extends State<NoteColorPickerDialog> {
  late bool _gradient = isGradientColor(widget.current);
  late List<String> _stops = _gradient
      ? gradientStopHexes(widget.current)
      : [widget.current, kNoteColorHexes[1]];
  int _activeStop = 0;
  late Color _pickerColor =
      colorFromHex(_gradient ? _stops[0] : _currentSolidHex());

  void _setActiveStop(int i) {
    setState(() {
      _activeStop = i;
      _pickerColor = colorFromHex(_stops[i]);
    });
  }

  void _applyPreset(String hex) {
    if (_gradient) {
      setState(() {
        _stops[_activeStop] = hex;
        _pickerColor = colorFromHex(hex);
      });
    } else {
      Navigator.pop(context, hex);
    }
  }

  void _onPickerColorChanged(Color c) {
    setState(() {
      _pickerColor = c;
      if (_gradient) _stops[_activeStop] = hexFromColor(c);
    });
  }

  void _addStop() {
    if (_stops.length >= 3) return;
    setState(() {
      _stops.add(kNoteColorHexes[(_stops.length + 2) % kNoteColorHexes.length]);
      _activeStop = _stops.length - 1;
      _pickerColor = colorFromHex(_stops[_activeStop]);
    });
  }

  void _removeStop(int i) {
    if (_stops.length <= 2) return;
    setState(() {
      _stops.removeAt(i);
      _activeStop = _activeStop.clamp(0, _stops.length - 1);
      _pickerColor = colorFromHex(_stops[_activeStop]);
    });
  }

  /// The single hex to show/highlight in Solid mode — [widget.current] itself
  /// if the dialog opened on a solid note, or the first gradient stop as a
  /// fallback reference point if it opened on a gradient note (so toggling
  /// modes never tries to treat a "grad:..." string as a plain hex).
  String _currentSolidHex() =>
      isGradientColor(widget.current) ? _stops.first : widget.current;

  void _setGradientMode(bool gradient) {
    setState(() {
      _gradient = gradient;
      if (_gradient && _stops.length < 2) {
        _stops = [_currentSolidHex(), kNoteColorHexes[1]];
      }
      _activeStop = 0;
      _pickerColor = colorFromHex(_gradient ? _stops[0] : _currentSolidHex());
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: NotallyColors.surface,
      title: Row(
        children: [
          const Expanded(
            child: Text('Note color',
                style: TextStyle(color: NotallyColors.textBright, fontSize: 16)),
          ),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Solid')),
              ButtonSegment(value: true, label: Text('Gradient')),
            ],
            selected: {_gradient},
            onSelectionChanged: (s) => _setGradientMode(s.first),
          ),
        ],
      ),
      content: SizedBox(
        width: 300,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_gradient) ...[
                _stopsRow(),
                const SizedBox(height: 12),
                Container(
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: LinearGradient(
                        colors: _stops.map(colorFromHex).toList()),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: kNoteColorHexes.map((hex) {
                  final selected = _gradient
                      ? _stops[_activeStop] == hex
                      : hex == _currentSolidHex();
                  return GestureDetector(
                    onTap: () => _applyPreset(hex),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colorFromHex(hex),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? NotallyColors.accent : NotallyColors.border,
                          width: selected ? 3 : 1.5,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check,
                              color: NotallyColors.accent, size: 16)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // The real saturation/value + hue picker, for any custom color
              // (not just the presets above) — its own hex field doubles as
              // the "type a hex code" entry point.
              ColorPicker(
                pickerColor: _pickerColor,
                onColorChanged: _onPickerColorChanged,
                paletteType: PaletteType.hsvWithHue,
                enableAlpha: false,
                labelTypes: const [],
                displayThumbColor: true,
                hexInputBar: true,
                // The package otherwise picks its layout from screen
                // orientation, not the dialog's own width — on a wide
                // desktop window that means a side-by-side layout that
                // overflows this narrow dialog. Force the stacked layout.
                portraitOnly: true,
                colorPickerWidth: 268,
                pickerAreaHeightPercent: 0.7,
                pickerAreaBorderRadius: BorderRadius.circular(8),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context,
              _gradient ? encodeGradient(_stops) : hexFromColor(_pickerColor)),
          child: Text(_gradient ? 'Apply gradient' : 'Apply'),
        ),
      ],
    );
  }

  Widget _stopsRow() {
    return Row(
      children: [
        for (var i = 0; i < _stops.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: GestureDetector(
              onTap: () => _setActiveStop(i),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colorFromHex(_stops[i]),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            i == _activeStop ? NotallyColors.accent : NotallyColors.border,
                        width: i == _activeStop ? 3 : 1.5,
                      ),
                    ),
                  ),
                  if (_stops.length > 2)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: GestureDetector(
                        onTap: () => _removeStop(i),
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: NotallyColors.surface,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 12, color: NotallyColors.textFaint),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (_stops.length < 3)
          GestureDetector(
            onTap: _addStop,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: NotallyColors.border, width: 1.5),
              ),
              child: const Icon(Icons.add,
                  color: NotallyColors.textFaint, size: 18),
            ),
          ),
      ],
    );
  }
}

/// Result of [HeadingPickerDialog]: [level] is 1-3 for a heading size, or
/// `null` to remove any heading from the selected line(s).
class HeadingResult {
  const HeadingResult(this.level);

  final int? level;
}

/// Lets the user pick a heading level (or remove one) for the line(s) the
/// current selection touches. Pops `null` if dismissed without a choice.
class HeadingPickerDialog extends StatelessWidget {
  const HeadingPickerDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: NotallyColors.surface,
      title: const Text('Heading',
          style: TextStyle(color: NotallyColors.textBright, fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final level in [1, 2, 3])
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Heading $level',
                style: TextStyle(
                  color: NotallyColors.textBright,
                  fontSize: 22 - level * 3,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => Navigator.pop(context, HeadingResult(level)),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Remove heading',
                style: TextStyle(color: NotallyColors.accent)),
            onTap: () => Navigator.pop(context, const HeadingResult(null)),
          ),
        ],
      ),
    );
  }
}

/// Result of [NoteExpiryDialog]: [at] is the absolute moment the note should
/// self-destruct, or `null` to turn the timer off.
class NoteExpiryResult {
  const NoteExpiryResult(this.at);

  final DateTime? at;
}

/// Lets the user set (or clear) a note's self-destruct timer, either via a
/// quick preset or by manually picking an exact date and time. Pops `null`
/// if dismissed without a choice.
class NoteExpiryDialog extends StatelessWidget {
  const NoteExpiryDialog({super.key, required this.current});

  final int? current;

  static const _options = [
    (label: '1 hour', duration: Duration(hours: 1)),
    (label: '1 day', duration: Duration(days: 1)),
    (label: '7 days', duration: Duration(days: 7)),
    (label: '30 days', duration: Duration(days: 30)),
  ];

  Future<void> _pickCustom(BuildContext context) async {
    final now = DateTime.now();
    final currentAt =
        current != null ? DateTime.fromMillisecondsSinceEpoch(current!) : null;
    final initialDate =
        currentAt != null && currentAt.isAfter(now) ? currentAt : now;

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null || !context.mounted) return;

    final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (!picked.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a time in the future')),
      );
      return;
    }
    Navigator.pop(context, NoteExpiryResult(picked));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: NotallyColors.surface,
      title: const Text(
        'Self-destruct timer',
        style: TextStyle(color: NotallyColors.textBright, fontSize: 16),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in _options)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(o.label,
                  style: const TextStyle(color: NotallyColors.textPrimary)),
              trailing: const Icon(Icons.hourglass_bottom,
                  color: NotallyColors.textFaint, size: 18),
              onTap: () => Navigator.pop(
                  context, NoteExpiryResult(DateTime.now().add(o.duration))),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Custom date & time…',
                style: TextStyle(color: NotallyColors.textPrimary)),
            trailing: const Icon(Icons.edit_calendar,
                color: NotallyColors.textFaint, size: 18),
            onTap: () => _pickCustom(context),
          ),
          if (current != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Turn off',
                  style: TextStyle(color: NotallyColors.accent)),
              trailing:
                  const Icon(Icons.hourglass_disabled, color: NotallyColors.accent, size: 18),
              onTap: () => Navigator.pop(context, const NoteExpiryResult(null)),
            ),
        ],
      ),
    );
  }
}
