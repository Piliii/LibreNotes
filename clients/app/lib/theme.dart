import 'package:flutter/material.dart';

/// Preset note background colors (hex, same format stored in the Note model).
const kNoteColorHexes = [
  '#2a2a2a', // default dark
  '#3d2020', // rust
  '#3d3120', // amber
  '#263d20', // forest
  '#20353d', // teal
  '#20273d', // ocean
  '#2d203d', // violet
];

/// Converts a stored hex color string (e.g. "#2a2a2a") to a Flutter [Color].
Color colorFromHex(String hex) {
  final h = hex.startsWith('#') ? hex.substring(1) : hex;
  return Color(int.parse('FF$h', radix: 16));
}

/// The inverse of [colorFromHex] — a Flutter [Color] back to a stored hex
/// string (e.g. "#2a2a2a"), dropping alpha since note colors are opaque.
String hexFromColor(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

/// A note's stored `color` is either a plain hex string (a preset or a
/// custom color, e.g. "#2a2a2a") or, for a gradient, `grad:` followed by 2-3
/// comma-separated hex stops (e.g. "grad:#2a2a2a,#20353d"). This is a plain
/// string on purpose: it's what's already stored in the `color` TEXT column
/// and threaded opaquely through the encrypted sync payload, so encoding a
/// gradient this way needs no schema migration and no changes outside the
/// client UI layer — everything else just keeps passing a `String` through.
const _gradientPrefix = 'grad:';

bool isGradientColor(String color) => color.startsWith(_gradientPrefix);

List<String> gradientStopHexes(String color) =>
    color.substring(_gradientPrefix.length).split(',');

String encodeGradient(List<String> stopHexes) =>
    '$_gradientPrefix${stopHexes.join(',')}';

/// A note's color as 1-3 base [Color]s: a single color for a solid note, or
/// the user's own stops (in order) for a gradient note.
List<Color> noteBaseColors(String color) => isGradientColor(color)
    ? gradientStopHexes(color).map(colorFromHex).toList()
    : [colorFromHex(color)];

/// A plain background decoration for [color] — solid fill, or a diagonal
/// linear gradient of its stops. For the editor surfaces, which just need to
/// show the note's actual color(s) (unlike the card/list rows, which layer
/// an extra lighter/darker "sheen" on top — see their own gradient logic).
BoxDecoration noteBackgroundDecoration(String color) {
  final bases = noteBaseColors(color);
  if (bases.length == 1) return BoxDecoration(color: bases.first);
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: bases,
    ),
  );
}

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

/// A resolved set of text tones guaranteed to stay readable against a given
/// note background. The fixed `NotallyColors.text*` tones are light-on-dark
/// by design (they assume the app's own dark background) and silently lose
/// contrast once a note's own custom/gradient color leans light — e.g. a
/// near-white note would render near-white text on a near-white background.
class NoteTextColors {
  const NoteTextColors({
    required this.bright,
    required this.primary,
    required this.muted,
    required this.faint,
  });

  final Color bright;
  final Color primary;
  final Color muted;
  final Color faint;

  static const _onDark = NoteTextColors(
    bright: NotallyColors.textBright,
    primary: NotallyColors.textPrimary,
    muted: NotallyColors.textMuted,
    faint: NotallyColors.textFaint,
  );

  static const _onLight = NoteTextColors(
    bright: Color(0xFF000000),
    primary: Color(0xFF1A1A1A),
    muted: Color(0xFF4D4D4D),
    faint: Color(0xFF666666),
  );

  /// WCAG AA minimum contrast ratio for normal-sized text. Used as the actual
  /// bar for "readable," rather than a naive luminance midpoint.
  static const _minContrastRatio = 4.5;

  /// Resolves the right tone set for a note's stored `color` (a solid hex or
  /// a `grad:` gradient string).
  ///
  /// Picks whichever family's brightest tone (pure white vs. pure black)
  /// clears [_minContrastRatio] against the background — using the *lightest*
  /// of the background's stops, not their average, so a gradient with even
  /// one light patch switches the whole note to dark text instead of letting
  /// that one patch wash out. This is deliberately stricter than a 50%
  /// luminance split: the luminance level at which white text actually stops
  /// clearing 4.5:1 contrast is much lower than 0.5 (around ~0.18), so this
  /// switches to dark text on plenty of "medium" backgrounds a midpoint check
  /// would have left on light text.
  factory NoteTextColors.forBackground(String color) {
    final bases = noteBaseColors(color);
    final maxLuminance =
        bases.map((c) => c.computeLuminance()).reduce((a, b) => a > b ? a : b);
    // WCAG contrast ratio of pure white against a background of this
    // luminance: (1.0 + 0.05) / (L + 0.05).
    final whiteContrast = 1.05 / (maxLuminance + 0.05);
    return whiteContrast < _minContrastRatio ? _onLight : _onDark;
  }
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

/// Read-only note body text (archive/trash previews).
const kNoteBodyStyle =
    TextStyle(color: NotallyColors.textPrimary, fontSize: 16, height: 1.5);
