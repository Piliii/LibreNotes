import 'package:flutter/material.dart';

/// Shown at startup instead of the normal app when this binary's schema
/// ([DatabaseTooNewException.supported]) is older than the schema already on
/// the local database ([DatabaseTooNewException.onDisk]) — meaning a newer
/// install of LibreNotes already opened this database. Nothing has been
/// touched: the safe move is to update rather than let an old build guess at
/// a newer schema.
class OutdatedAppScreen extends StatelessWidget {
  const OutdatedAppScreen({
    super.key,
    required this.onDiskVersion,
    required this.supportedVersion,
  });

  final int onDiskVersion;
  final int supportedVersion;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff1a1a1a),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.system_update_alt,
                    color: Color(0xffff6900), size: 40),
                const SizedBox(height: 16),
                const Text(
                  'This app is out of date',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your notes on this device were last opened by a newer '
                  'version of LibreNotes (database schema $onDiskVersion), '
                  'but this build only understands schema $supportedVersion. '
                  "Nothing has been changed — update LibreNotes to the "
                  'latest version and reopen it.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
