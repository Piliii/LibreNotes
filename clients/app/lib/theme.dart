import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

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
    ? gradientStopHexes(color).map(noteDisplayColor).toList()
    : [noteDisplayColor(color)];

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

/// One full set of surface/text tones. [dark] is the original prototype's
/// palette; [light] is its daylight counterpart (same roles, same orange).
class NotallyPalette {
  const NotallyPalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.card,
    required this.cardActive,
    required this.border,
    required this.textPrimary,
    required this.textBright,
    required this.textMuted,
    required this.textFaint,
    required this.danger,
    required this.scrollThumb,
    required this.overlay,
  });

  final Brightness brightness;
  final Color background, surface, card, cardActive, border;
  final Color textPrimary, textBright, textMuted, textFaint;
  final Color danger, scrollThumb;

  /// Base for translucent hover/divider/outline tints: white on dark, black
  /// on light. Use as `overlay.withValues(alpha: …)`.
  final Color overlay;

  static const dark = NotallyPalette(
    brightness: Brightness.dark,
    background: Color(0xFF1A1A1A),
    surface: Color(0xFF242424), // sidebar
    card: Color(0xFF2A2A2A),
    cardActive: Color(0xFF3A3A3A),
    border: Color(0xFF333333),
    textPrimary: Color(0xFFE0E0E0),
    textBright: Color(0xFFFFFFFF),
    textMuted: Color(0xFF999999),
    textFaint: Color(0xFF888888),
    danger: Color(0xFFE57373),
    scrollThumb: Color(0xFF444444),
    overlay: Color(0xFFFFFFFF),
  );

  static const light = NotallyPalette(
    brightness: Brightness.light,
    background: Color(0xFFF4F4F2),
    surface: Color(0xFFFBFBFA), // sidebar
    card: Color(0xFFFFFFFF),
    cardActive: Color(0xFFE6E6E3),
    border: Color(0xFFDEDEDB),
    textPrimary: Color(0xFF242424),
    textBright: Color(0xFF000000),
    textMuted: Color(0xFF5E5E5E),
    textFaint: Color(0xFF6B6B6B),
    danger: Color(0xFFC62828),
    scrollThumb: Color(0xFFC4C4C0),
    overlay: Color(0xFF000000),
  );
}

/// The user's theme choice, persisted as `pref.theme` by `NotallyApp`.
final themeModeNotifier = ValueNotifier(ThemeMode.system);

/// Cycles the theme choice System → Light → Dark.
void cycleThemeMode() => themeModeNotifier.value =
    ThemeMode.values[(themeModeNotifier.value.index + 1) % ThemeMode.values.length];

/// The app palette. Reads go through the *active* [NotallyPalette], which
/// `NotallyApp` swaps via [use] when the theme mode or OS brightness changes.
// ponytail: a global palette + whole-tree rebuild instead of a
// ThemeExtension threaded through ~300 call sites; switch to
// `Theme.of(context).extension` if per-subtree theming is ever needed.
abstract final class NotallyColors {
  static NotallyPalette _p = NotallyPalette.dark;
  static NotallyPalette get palette => _p;
  static bool get isLight => _p.brightness == Brightness.light;

  /// Activates the palette for [b]; returns whether it changed.
  static bool use(Brightness b) {
    final next = b == Brightness.light ? NotallyPalette.light : NotallyPalette.dark;
    if (identical(next, _p)) return false;
    _p = next;
    return true;
  }

  static const accent = Color(0xFFFF6900); // orange, both themes
  static const success = Color(0xFF4CAF50);
  static Color get background => _p.background;
  static Color get surface => _p.surface;
  static Color get card => _p.card;
  static Color get cardActive => _p.cardActive;
  static Color get border => _p.border;
  static Color get textPrimary => _p.textPrimary;
  static Color get textBright => _p.textBright;
  static Color get textMuted => _p.textMuted;
  static Color get textFaint => _p.textFaint;
  static Color get danger => _p.danger;
  static Color get overlay => _p.overlay;
}

/// Light-theme stand-ins for the dark presets in [kNoteColorHexes]: the
/// stored value stays the dark hex (so it syncs unchanged to dark-theme
/// devices) and only its on-screen color is swapped. Custom colors render
/// as-is in both themes.
const _lightPresets = {
  '#2a2a2a': Color(0xFFFFFFFF), // default → plain card
  '#3d2020': Color(0xFFF6D9D4), // rust
  '#3d3120': Color(0xFFF5E7C8), // amber
  '#263d20': Color(0xFFDAEBD3), // forest
  '#20353d': Color(0xFFD2E8EE), // teal
  '#20273d': Color(0xFFD6DDF2), // ocean
  '#2d203d': Color(0xFFE5DAF2), // violet
};

/// On-screen color for a stored note color hex: [colorFromHex], except a
/// preset in the light theme shows its light stand-in.
Color noteDisplayColor(String hex) =>
    (NotallyColors.isLight ? _lightPresets[hex.toLowerCase()] : null) ??
    colorFromHex(hex);

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
    bright: Color(0xFFFFFFFF),
    primary: Color(0xFFE0E0E0),
    muted: Color(0xFF999999),
    faint: Color(0xFF888888),
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

/// The six text roles every screen maps to (system font; see DESIGN.md).
abstract final class NotallyType {
  static TextStyle get display => TextStyle(
      color: NotallyColors.textBright,
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 1.2);
  static TextStyle get title => TextStyle(
      color: NotallyColors.textBright,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.3);
  static TextStyle get subtitle => TextStyle(
      color: NotallyColors.textBright,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.4);
  static TextStyle get body => TextStyle(
      color: NotallyColors.textPrimary, fontSize: 16, height: 1.5);
  static TextStyle get label => TextStyle(
      color: NotallyColors.textPrimary,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 1.3);
  static TextStyle get caption => TextStyle(
      color: NotallyColors.textFaint, fontSize: 11, height: 1.3);
}

/// Corner radii: controls 8, cards/rows 12, pills 20.
abstract final class NotallyRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 20.0;
}

/// Theme for the active [NotallyColors.palette].
ThemeData buildNotallyTheme() {
  const c = NotallyColors.accent;
  final base = NotallyColors.isLight
      ? ThemeData.light(useMaterial3: true)
      : ThemeData.dark(useMaterial3: true);

  return base.copyWith(
    // One icon-button look everywhere: faint 20px glyph, 8px hover shape.
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: NotallyColors.textFaint,
        iconSize: 20,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NotallyRadius.sm)),
      ),
    ),
    // Menus: charcoal surface, 12px corners, label-sized rows. They float, so
    // they alone carry a shadow.
    popupMenuTheme: PopupMenuThemeData(
      color: NotallyColors.surface,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: NotallyColors.isLight ? 0.25 : 1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NotallyRadius.md),
        side: BorderSide(color: NotallyColors.border),
      ),
      textStyle: NotallyType.label,
    ),
    dividerTheme: DividerThemeData(color: NotallyColors.border, space: 1),
    scaffoldBackgroundColor: NotallyColors.background,
    colorScheme: base.colorScheme.copyWith(
      primary: c,
      secondary: c,
      surface: NotallyColors.surface,
      onSurface: NotallyColors.textPrimary,
      // M3's baseline light scheme tints dialogs/sheets lavender; keep them
      // on the neutral palette instead.
      surfaceContainerLowest: NotallyColors.isLight ? NotallyColors.card : null,
      surfaceContainerLow: NotallyColors.isLight ? NotallyColors.card : null,
      surfaceContainer: NotallyColors.isLight ? NotallyColors.surface : null,
      surfaceContainerHigh: NotallyColors.isLight ? NotallyColors.card : null,
      surfaceContainerHighest:
          NotallyColors.isLight ? NotallyColors.cardActive : null,
      outline: NotallyColors.isLight ? NotallyColors.textFaint : null,
      outlineVariant: NotallyColors.isLight ? NotallyColors.border : null,
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
      thumbColor: WidgetStateProperty.all(NotallyColors.palette.scrollThumb),
      thickness: WidgetStateProperty.all(8),
      radius: const Radius.circular(4),
    ),
  );
}

/// Read-only note body text (archive/trash previews).
TextStyle get kNoteBodyStyle =>
    TextStyle(color: NotallyColors.textPrimary, fontSize: 16, height: 1.5);

/// Markdown rendering styled for the dark theme (used by the editor preview).
/// [colors] lets callers rendering on top of a note's own custom/gradient
/// background (see [NoteTextColors]) swap in a readable tone set instead of
/// the default dark-background tones.
MarkdownStyleSheet notallyMarkdownStyle({NoteTextColors? colors}) {
  final c = colors ?? NoteTextColors.forBackground(kNoteColorHexes.first);
  final body = TextStyle(color: c.primary, fontSize: 16, height: 1.5);
  TextStyle heading(double size) => TextStyle(
        color: c.bright,
        fontSize: size,
        fontWeight: FontWeight.w600,
        height: 1.3,
      );
  return MarkdownStyleSheet(
    p: body,
    h1: heading(28),
    h2: heading(24),
    h3: heading(20),
    h4: heading(18),
    h5: heading(16),
    h6: heading(16),
    listBullet: body,
    checkbox: body,
    strong: TextStyle(color: c.bright, fontWeight: FontWeight.w700),
    em: TextStyle(color: c.primary, fontStyle: FontStyle.italic),
    a: const TextStyle(color: NotallyColors.accent),
    code: TextStyle(
      color: NotallyColors.accent,
      backgroundColor: c.primary.withValues(alpha: 0.08),
      fontFamily: 'monospace',
      fontSize: 14,
    ),
    codeblockDecoration: BoxDecoration(
      color: c.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
    ),
    codeblockPadding: const EdgeInsets.all(12),
    blockquote: TextStyle(color: c.muted),
    blockquoteDecoration: const BoxDecoration(
      border: Border(left: BorderSide(color: NotallyColors.accent, width: 3)),
    ),
    blockquotePadding: const EdgeInsets.only(left: 12),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: c.faint.withValues(alpha: 0.4))),
    ),
  );
}
