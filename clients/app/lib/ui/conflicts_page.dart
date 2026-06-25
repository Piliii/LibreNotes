import 'package:flutter/material.dart';

import '../format.dart';
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
