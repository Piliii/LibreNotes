import 'package:flutter/material.dart';

import '../theme.dart';

const _shortcuts = [
  ('Ctrl+N', 'New note'),
  ('Ctrl+F', 'Focus search'),
  ('Ctrl+E', 'Toggle preview'),
  ('Ctrl+Shift+A', 'Archive note'),
  ('Ctrl+Shift+Del', 'Move note to Trash'),
  ('Ctrl+/ or F1', 'Show this help'),
];

Future<void> showShortcutsHelp(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => AlertDialog(
    backgroundColor: NotallyColors.surface,
    title: const Text('Keyboard shortcuts'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (keys, what) in _shortcuts)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 140,
                  child: Text(
                    keys,
                    style: const TextStyle(
                      color: NotallyColors.accent,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                Expanded(child: Text(what)),
              ],
            ),
          ),
      ],
    ),
  ),
);
