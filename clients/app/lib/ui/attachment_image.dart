import 'dart:io' show File, Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/notes_repository.dart';
import '../theme.dart';

/// An embedded note image (`![](attachment:<id>)`), shown in place of its
/// link in both Edit and Preview. The link itself is only reachable through
/// this widget's menu (right-click / long-press): Copy image link, Save
/// image as…, Remove image.
class AttachmentImage extends StatefulWidget {
  const AttachmentImage({
    super.key,
    required this.repo,
    required this.noteId,
    required this.id,
    this.onRemove,
    this.maxHeight = 360,
  });

  final NotesRepository repo;
  final String noteId;
  final String id;

  /// Removes the image from the note; the menu entry is hidden when null.
  final VoidCallback? onRemove;
  final double maxHeight;

  @override
  State<AttachmentImage> createState() => _AttachmentImageState();
}

class _AttachmentImageState extends State<AttachmentImage> {
  late Future<Uint8List?> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AttachmentImage old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) _load();
  }

  void _load() {
    final cached = widget.repo.cachedImage(widget.id);
    _future = cached != null
        ? Future.value(cached)
        : widget.repo.loadImage(widget.id, widget.noteId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      initialData: widget.repo.cachedImage(widget.id),
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes == null) {
          final loading = snap.connectionState != ConnectionState.done;
          return _frame(
            context,
            null,
            Container(
              height: 72,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(NotallyRadius.sm),
              ),
              child: loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: NotallyColors.accent))
                  : InkWell(
                      onTap: () => setState(_load),
                      child: Text(
                        '🖼 Image not available yet. Tap to retry.',
                        style: TextStyle(
                            color: NotallyColors.textFaint, fontSize: 13),
                      ),
                    ),
            ),
          );
        }
        return _frame(
          context,
          bytes,
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.maxHeight),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(NotallyRadius.sm),
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                semanticLabel: 'Image',
                errorBuilder: (_, _, _) => Text('🖼 Unreadable image',
                    style: TextStyle(
                        color: NotallyColors.textFaint, fontSize: 13)),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _frame(BuildContext context, Uint8List? bytes, Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapUp: (d) => _menu(context, d.globalPosition, bytes),
        onLongPressStart: (d) => _menu(context, d.globalPosition, bytes),
        child: MouseRegion(cursor: SystemMouseCursors.basic, child: child),
      ),
    );
  }

  Future<void> _menu(
      BuildContext context, Offset pos, Uint8List? bytes) async {
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
      items: [
        const PopupMenuItem(value: 'copy', child: Text('Copy image link')),
        if (bytes != null)
          const PopupMenuItem(value: 'save', child: Text('Save image as…')),
        if (widget.onRemove != null)
          const PopupMenuItem(value: 'remove', child: Text('Remove image')),
      ],
    );
    switch (choice) {
      case 'copy':
        await Clipboard.setData(
            ClipboardData(text: '![](attachment:${widget.id})'));
      case 'save':
        try {
          await _save(bytes!);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
                content: Text("Couldn't save the image there. Pick another "
                    'folder, or check that you can write to it.')));
          }
        }
      case 'remove':
        widget.onRemove?.call();
    }
  }

  Future<void> _save(Uint8List bytes) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save image',
      fileName: 'image.${widget.id.split('.').last}',
      bytes: bytes,
    );
    // On desktop the picker only returns the path; write the file ourselves.
    if (path != null && !kIsWeb && (Platform.isLinux || Platform.isWindows)) {
      await File(path).writeAsBytes(bytes);
    }
  }
}
