import 'package:flutter/material.dart';

import '../format.dart';
import '../line_diff.dart';
import '../sync/sync_service.dart';
import '../theme.dart';

/// Resolves sync conflicts: for each note edited on two devices, the user keeps
/// either their device's version or the server's.
class ConflictsPage extends StatelessWidget {
  const ConflictsPage({super.key, required this.service});

  final SyncService service;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NotallyColors.background,
      appBar: AppBar(
        backgroundColor: NotallyColors.background,
        elevation: 0,
        title: const Text('Resolve conflicts',
            style: TextStyle(color: NotallyColors.textBright)),
        iconTheme: const IconThemeData(color: NotallyColors.textPrimary),
      ),
      body: SafeArea(
        child: ValueListenableBuilder<List<SyncConflict>>(
          valueListenable: service.conflicts,
          builder: (context, conflicts, __) {
            if (conflicts.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: Color(0xFF4CAF50), size: 56),
                    SizedBox(height: 14),
                    Text('All conflicts resolved',
                        style: TextStyle(
                            color: NotallyColors.textMuted, fontSize: 16)),
                  ],
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: conflicts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (_, i) =>
                  _ConflictCard(service: service, conflict: conflicts[i]),
            );
          },
        ),
      ),
    );
  }
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({required this.service, required this.conflict});

  final SyncService service;
  final SyncConflict conflict;

  @override
  Widget build(BuildContext context) {
    final local = conflict.local;
    final remote = conflict.remote;
    final title = local.title.isEmpty ? 'Untitled' : local.title;

    return Container(
      decoration: BoxDecoration(
        color: NotallyColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NotallyColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: NotallyColors.textBright,
                  fontSize: 17,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          _Version(
            label: 'This device',
            title: local.title,
            body: local.body,
            updatedAt: local.updatedAt,
            deleted: local.deleted,
            onKeep: () => service.keepLocal(conflict.id),
          ),
          const SizedBox(height: 10),
          _Version(
            label: 'Server',
            title: remote.title,
            body: remote.body,
            updatedAt: remote.updatedAt,
            deleted: remote.deleted,
            onKeep: () => service.keepRemote(conflict.id),
          ),
          if (!local.deleted && !remote.deleted) ...[
            const SizedBox(height: 10),
            _DiffView(local: local.body, remote: remote.body),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        _MergePage(service: service, conflict: conflict))),
                icon: const Icon(Icons.edit_note, size: 18),
                label: const Text('Merge manually'),
                style: TextButton.styleFrom(
                    foregroundColor: NotallyColors.accent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Version extends StatelessWidget {
  const _Version({
    required this.label,
    required this.title,
    required this.body,
    required this.updatedAt,
    required this.deleted,
    required this.onKeep,
  });

  final String label;
  final String title;
  final String body;
  final int updatedAt;
  final bool deleted;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NotallyColors.card,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label.toUpperCase(),
                  style: const TextStyle(
                      color: NotallyColors.textFaint,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
              const Spacer(),
              Text(relativeTime(updatedAt),
                  style: const TextStyle(
                      color: NotallyColors.textFaint, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            deleted
                ? '(deleted)'
                : (previewText(body).isEmpty
                    ? (title.isEmpty ? '(empty)' : title)
                    : previewText(body)),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: deleted
                    ? NotallyColors.textFaint
                    : NotallyColors.textPrimary,
                fontSize: 13,
                height: 1.4,
                fontStyle: deleted ? FontStyle.italic : FontStyle.normal),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onKeep,
              style: TextButton.styleFrom(
                foregroundColor: NotallyColors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('Keep this'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Collapsible line diff: red = only on this device, green = only on server.
class _DiffView extends StatelessWidget {
  const _DiffView({required this.local, required this.remote});
  final String local;
  final String remote;

  static const _red = Color(0xFFE57373);
  static const _green = Color(0xFF81C784);

  @override
  Widget build(BuildContext context) {
    final lines = diffLines(local, remote);
    if (lines.every((l) => l.op == DiffOp.same)) {
      return const Text('Text is identical — only metadata differs.',
          style: TextStyle(color: NotallyColors.textFaint, fontSize: 12));
    }
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        iconColor: NotallyColors.textFaint,
        collapsedIconColor: NotallyColors.textFaint,
        title: const Text('Show differences',
            style: TextStyle(color: NotallyColors.textMuted, fontSize: 13)),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: NotallyColors.card,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('− this device    + server',
                    style:
                        TextStyle(color: NotallyColors.textFaint, fontSize: 11)),
                const SizedBox(height: 6),
                for (final l in lines)
                  Container(
                    width: double.infinity,
                    color: switch (l.op) {
                      DiffOp.removed => _red.withValues(alpha: 0.18),
                      DiffOp.added => _green.withValues(alpha: 0.18),
                      DiffOp.same => null,
                    },
                    child: Text(
                      '${switch (l.op) {
                        DiffOp.removed => '− ',
                        DiffOp.added => '+ ',
                        DiffOp.same => '  ',
                      }}${l.text}',
                      style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.4,
                          color: switch (l.op) {
                            DiffOp.removed => _red,
                            DiffOp.added => _green,
                            DiffOp.same => NotallyColors.textPrimary,
                          }),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Manual-merge editor: starts from both versions interleaved with conflict
/// markers; saving pushes the result as this device's version.
class _MergePage extends StatefulWidget {
  const _MergePage({required this.service, required this.conflict});
  final SyncService service;
  final SyncConflict conflict;

  @override
  State<_MergePage> createState() => _MergePageState();
}

class _MergePageState extends State<_MergePage> {
  late final _title = TextEditingController(text: widget.conflict.local.title);
  late final _body = TextEditingController(
      text: mergeWithMarkers(
          widget.conflict.local.body, widget.conflict.remote.body));
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (hasConflictMarkers(_body.text)) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Unresolved markers'),
          content: const Text(
              'The text still has <<<<<<< / ======= / >>>>>>> lines. Save anyway?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep editing')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save anyway')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _saving = true);
    await widget.service.keepMerged(widget.conflict.id,
        title: _title.text, body: _body.text);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NotallyColors.background,
      appBar: AppBar(
        backgroundColor: NotallyColors.background,
        elevation: 0,
        title: const Text('Merge manually',
            style: TextStyle(color: NotallyColors.textBright)),
        iconTheme: const IconThemeData(color: NotallyColors.textPrimary),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save merged',
                style: TextStyle(color: NotallyColors.accent)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _title,
                style: const TextStyle(
                    color: NotallyColors.textBright, fontSize: 17),
                decoration: const InputDecoration(hintText: 'Title'),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: _body,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                      color: NotallyColors.textPrimary,
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
