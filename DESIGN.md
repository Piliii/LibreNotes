---
name: LibreNotes
description: A dark, quiet desk lit by one orange lamp: private, offline-first markdown notes.
colors:
  accent: "#ff6900"
  background: "#1a1a1a"
  surface: "#242424"
  card: "#2a2a2a"
  card-active: "#3a3a3a"
  border: "#333333"
  text-primary: "#e0e0e0"
  text-bright: "#ffffff"
  text-muted: "#999999"
  text-faint: "#888888"
  success: "#4caf50"
  danger: "#e57373"
typography:
  display:
    fontFamily: "system-ui, Roboto, sans-serif"
    fontSize: "28px"
    fontWeight: 700
    lineHeight: 1.2
  title:
    fontFamily: "system-ui, Roboto, sans-serif"
    fontSize: "20px"
    fontWeight: 600
    lineHeight: 1.3
  subtitle:
    fontFamily: "system-ui, Roboto, sans-serif"
    fontSize: "16px"
    fontWeight: 600
    lineHeight: 1.4
  body:
    fontFamily: "system-ui, Roboto, sans-serif"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.5
  label:
    fontFamily: "system-ui, Roboto, sans-serif"
    fontSize: "13px"
    fontWeight: 500
    lineHeight: 1.3
  caption:
    fontFamily: "system-ui, Roboto, sans-serif"
    fontSize: "11px"
    fontWeight: 400
    lineHeight: 1.3
rounded:
  sm: "8px"
  md: "12px"
  lg: "20px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "20px"
components:
  button-primary:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.text-bright}"
    rounded: "{rounded.sm}"
    padding: "8px 16px"
  input-search:
    backgroundColor: "{colors.background}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.sm}"
    padding: "8px 12px"
  note-card:
    backgroundColor: "{colors.card}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.md}"
    padding: "12px"
---

# Design System: LibreNotes

> Status: records the incumbent look plus the decisions confirmed on 2026-10-31 (North Star, hybrid elevation, system font with a single scale). Typography and radius/spacing values marked **target** are the standardised scale; the code today uses 15 font sizes and 8 radii and has no token layer beyond colours in `clients/app/lib/theme.dart`.

## Overview

**Creative North Star: "The Night Desk"**

A dark, quiet desk lit by one orange lamp. Surfaces step gently from near-black to charcoal, text is soft off-white, and the single orange accent appears only where the user acts or where state matters. The app should feel private and unhurried; capture and retrieval come first, chrome stays out of the way.

The same vocabulary applies on every form factor: a resizable list and editor on desktop, a staggered two-column card grid on Android. Note colours and gradients are the user's own expression; the app's chrome never competes with them.

**Key Characteristics:**
- Dark-only, tonal layering (`#1a1a1a` → `#242424` → `#2a2a2a`).
- One accent, `#ff6900`, used sparingly.
- System font on one six-step scale; no bundled font.
- Hybrid depth: flat at rest, soft shadow only on floating layers.

## Colors

Near-black neutrals with one saturated orange.

### Primary
- **Lamp Orange** (#ff6900): primary actions (New Note, FAB), focus rings, links, cursor and selection, expiry warnings, active toggles.

### Neutral
- **Desk Black** (#1a1a1a): app background and the editor canvas.
- **Sidebar Charcoal** (#242424): sidebar and menu surfaces.
- **Card Slate** (#2a2a2a): default note card and code blocks; also the default note colour.
- **Active Slate** (#3a3a3a): selected list row.
- **Hairline** (#333333): borders and dividers.
- **Soft White** (#e0e0e0) body text; **Bright White** (#ffffff) titles and strong text; **Muted** (#999999) previews; **Faint** (#888888) hints and metadata.

### Status
- **Sync Green** (#4caf50) and **Soft Red** (#e57373): sync state and destructive actions only.

### Note colours
Seven presets (`#2a2a2a`, `#3d2020`, `#3d3120`, `#263d20`, `#20353d`, `#20273d`, `#2d203d`), plus custom hex and 2–3 stop gradients. Text colour is resolved per note (`NoteTextColors.forBackground`) to hold 4.5:1 contrast.

### Light theme
Same roles, daylight values (`NotallyPalette.light` in `theme.dart`): background #f4f4f2, sidebar #fbfbfa, card #ffffff, active #e6e6e3, hairline #dededb, text #242424 / #000000 / #5e5e5e / #6b6b6b, danger #c62828. Orange is unchanged. Note presets keep their stored dark hex (so they sync unchanged) and display as pastel stand-ins; custom colours render as-is. Chosen via the overflow menu (System → Light → Dark), stored locally as `pref.theme`.

### Named Rules
**The One Lamp Rule.** Orange covers a small share of any screen: one primary action, focus and state. If two orange elements compete, one is wrong.

**The Note Owns Its Colour Rule.** A note's own colour is the only place a hue other than orange appears at scale; chrome stays neutral.

## Typography

**Font:** system UI font (Roboto on Android, platform default on desktop and web), no bundled face. Monospace for code.

**Character:** plain and legible; hierarchy comes from size and weight, not from typeface variety.

### Hierarchy (target scale, replaces 15 ad-hoc sizes)
- **Display** (700, 28px, 1.2): screen titles ("Notes"), editor title.
- **Title** (600, 20px, 1.3): section and dialog titles.
- **Subtitle** (600, 16px, 1.4): card and row titles.
- **Body** (400, 16px, 1.5): note body, preview text.
- **Label** (500, 13px, 1.3): buttons, menu rows, search, section labels.
- **Caption** (400, 11px, 1.3): timestamps, counts, metadata.

### Named Rules
**The Six Roles Rule.** Every text style maps to one of the six roles; hand-picked sizes are not allowed.

## Layout

Desktop: resizable sidebar (list) on the left, editor on the right, with the sidebar's header holding title, search and New Note. Mobile: staggered two-column masonry with 16px gutters and a bottom-right primary action. Spacing steps (target): 4, 8, 12, 20 (and multiples). Sidebar header padding is 20; list padding 10. Mobile touch targets 48dp; desktop controls keep visible keyboard focus.

## Elevation & Depth

Hybrid. Surfaces are flat at rest and separated by tone and hairline borders. Soft shadow appears only on floating layers: menus, dialogs, the FAB. No glass blur on persistent chrome (the current frosted editor pill is the exception being retired). Cards in lists today use a subtle sheen gradient over the note colour; keep it subtle and keep contrast intact.

### Named Rules
**The Flat-Until-Floating Rule.** Nothing casts a shadow unless it floats above the content.

## Shapes

Gently rounded. Target radii: **8px** for controls and inputs, **12px** for cards and list rows, **20px** for pills and chips. Borders are 1px Hairline; focus is a 1.5px orange border.

## Components

### Buttons
- **Primary:** Lamp Orange fill, white text, 8px radius. One per surface.
- **Icon button:** ghost, 20px icon in Faint, Bright on hover; 48dp touch area on mobile.

### Inputs
- **Search:** Desk Black fill, Hairline border, 8px radius, 13px label type; orange 1.5px border on focus.

### Cards / list rows
- **Card (mobile):** note colour fill, 12px radius, title (Subtitle) + 2–3 line preview (Body, Muted) + Caption timestamp; body-only preview when there is no title.
- **Row (desktop):** same hierarchy, single column; Active Slate when selected.

### Menus and dialogs
- Charcoal surface, Label-type rows with a leading 18px icon; destructive rows in Soft Red.

## Do's and Don'ts

### Do:
- **Do** use the six type roles and the 8/12/20 radius steps everywhere.
- **Do** keep one primary orange action per surface.
- **Do** put secondary actions in a single overflow menu, destructive ones last and in Soft Red.
- **Do** keep text on custom note colours readable via `NoteTextColors`.

### Don't:
- **Don't** add per-screen font sizes, radii or one-off colours.
- **Don't** use glass blur on persistent bars.
- **Don't** introduce a second accent colour or a light theme.
- **Don't** add dependencies for UI; Flutter-only, no Electron.
