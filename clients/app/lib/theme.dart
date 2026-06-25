import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// Notally's palette, lifted straight from the original prototype.
abstract final class NotallyColors {
  static const background = Color(0xFF1A1A1A);
  static const surface = Color(0xFF242424); // sidebar
  static const card = Color(0xFF2A2A2A);
  static const cardActive = Color(0xFF3A3A3A);
  static const accent = Color(0xFFFF6900); // orange
  static const border = Color(0xFF333333);
  static const textPrimary = Color(0xFFE0E0E0);
  static const textBright = Color(0xFFFFFFFF);
  static const textMuted = Color(0xFF999999);
  static const textFaint = Color(0xFF888888);
}

ThemeData buildNotallyTheme() {
  const c = NotallyColors.accent;
  final base = ThemeData.dark(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: NotallyColors.background,
    colorScheme: base.colorScheme.copyWith(
      primary: c,
      secondary: c,
      surface: NotallyColors.surface,
      onSurface: NotallyColors.textPrimary,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: c,
      selectionColor: Color(0x55FF6900),
      selectionHandleColor: c,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.all(const Color(0xFF444444)),
      thickness: WidgetStateProperty.all(8),
      radius: const Radius.circular(4),
    ),
  );
}

/// Markdown rendering styled for the dark theme (used by the editor preview).
MarkdownStyleSheet notallyMarkdownStyle() {
  const body = TextStyle(
      color: NotallyColors.textPrimary, fontSize: 16, height: 1.5);
  TextStyle heading(double size) => TextStyle(
        color: NotallyColors.textBright,
        fontSize: size,
        fontWeight: FontWeight.w600,
        height: 1.3,
      );
  return MarkdownStyleSheet(
    p: body,
    h1: heading(28),
    h2: heading(23),
    h3: heading(19),
    h4: heading(16),
    listBullet: body,
    strong: const TextStyle(
        color: NotallyColors.textBright, fontWeight: FontWeight.w700),
    em: const TextStyle(
        color: NotallyColors.textPrimary, fontStyle: FontStyle.italic),
    a: const TextStyle(color: NotallyColors.accent),
    code: const TextStyle(
      color: NotallyColors.accent,
      backgroundColor: Color(0xFF2A2A2A),
      fontFamily: 'monospace',
      fontSize: 14,
    ),
    codeblockDecoration: BoxDecoration(
      color: NotallyColors.card,
      borderRadius: BorderRadius.circular(8),
    ),
    codeblockPadding: const EdgeInsets.all(12),
    blockquote: const TextStyle(color: NotallyColors.textMuted),
    blockquoteDecoration: const BoxDecoration(
      border: Border(left: BorderSide(color: NotallyColors.accent, width: 3)),
    ),
    blockquotePadding: const EdgeInsets.only(left: 12),
    horizontalRuleDecoration: const BoxDecoration(
      border: Border(top: BorderSide(color: NotallyColors.border)),
    ),
  );
}
