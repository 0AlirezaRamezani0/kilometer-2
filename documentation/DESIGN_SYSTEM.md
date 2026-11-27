# Kilometer 2 — "Proving Ground" Design System (v0.1-b3)

Source of truth in code: `scripts/ui/ui_theme.gd` (tokens + the shared `Theme`),
`scripts/ui/ui_icon.gd` (icons), `scripts/ui/input_prompts.gd` (device prompts),
`scripts/ui/ui_modal_stack.gd` (overlay focus model). Every screen styles nodes through
`theme_type_variation` names; per-node overrides are reserved for live values.

## 1. Art direction

**Concept — a proving ground at night.** Kilometer 2 is set on an engineered test track:
distance gates, kerbs, a skid-pad, a lit showroom. The interface borrows the language of a
test-track control room and road signage rather than a generic racing "neon" look:

- **Graphite surfaces, ice-white type.** Calm, low-glare backgrounds that let the car and the
  track carry the colour. Glass panels keep the 3D scene visible behind menus.
- **One signal colour.** Vermilion means *go / selected / primary*. Exactly one filled
  vermilion button per screen (the call to action); selection is a vermilion outline + tint.
- **Telemetry semantics.** Throttle = green, brake = red, caution/handbrake = amber, info =
  cyan — the motorsport telemetry convention, never used for decoration and never alone
  (always paired with an icon, a label, a shape or a position).
- **The "speed slash".** The K2 badge's `//` becomes the heading mark (two slanted bars) —
  a brand motif that replaces the generic accent rail.
- **Persian first.** RTL layouts, Estedad typography, Persian digits in prose; Latin digits
  only inside instruments (speed, rpm, timer, IP addresses), following the existing project rule.

Why it fits: the game's identity was already "dark-sport, vermilion, Persian RTL" (B8/B9).
The redesign keeps that identity and the layouts the player approved (analog dual-dial
cluster, showroom-first flow, thumb-zone controls) and makes them consistent, readable on a
phone, accessible and honest.

### How Material Design 3 is used (foundation, not template)
Adopted: semantic colour roles with on-colours, a named type scale, state layers
(hover/pressed/focus/selected/disabled), a shape scale, motion tokens (durations + easing),
adaptive layout by window class, 8-dp spacing grid, 48-dp touch-target intent.
Not adopted: Roboto, light theme, FABs/app-bar chrome, dynamic colour — the game keeps its
own typeface, dark night palette and motorsport components.

## 2. Colour roles (dark scheme)

| Role | Token | Hex | Use |
|---|---|---|---|
| Background | `COLOR_BG` | `#07090D` | scene backdrop, LAN background |
| Surface | `COLOR_SURFACE` | `#0E131A` | sheets, drawer, HUD chips |
| Surface container (low → highest) | `COLOR_SURFACE_LOW/CONTAINER/HIGH/HIGHEST/BRIGHT` | `#121822` → `#313D50` | cards, default/hover/pressed button fills |
| Glass | `COLOR_GLASS` | surface-container @ 88 % | panels over the 3D scene |
| On-surface | `COLOR_ON_SURFACE` | `#F1F4F8` | primary text |
| On-surface variant | `COLOR_ON_SURFACE_VARIANT` | `#AAB5C5` | secondary text, captions |
| Disabled text | `COLOR_ON_SURFACE_DISABLED` | `#7F8A9B` | inactive labels |
| Outline / variant | `COLOR_OUTLINE` / `COLOR_OUTLINE_VARIANT` | `#5E6B7F` / white 10 % | component edges / hairlines |
| Primary (signal) | `COLOR_PRIMARY` | `#FF5A3C` | selection, icons, needles, headings mark |
| Primary container | `COLOR_PRIMARY_CONTAINER` (+hover `#DB2E1C`, pressed `#AE1F12`) | `#D2291A` | the filled CTA |
| Info | `COLOR_INFO` | `#56D8F0` | informational chips, headlight lamp |
| Success / throttle | `COLOR_SUCCESS` = `COLOR_THROTTLE` | `#2EDB91` | throttle, drive gear, saved |
| Warning / handbrake | `COLOR_WARNING` = `COLOR_HANDBRAKE` | `#FFB627` | handbrake, neutral gear, slippery surface |
| Error / brake | `COLOR_ERROR` = `COLOR_BRAKE` | `#FF5B6E` | brake, reverse, damage, destructive actions |
| Inverse surface | `COLOR_INVERSE_SURFACE` / on | `#EEF2F7` / `#10151C` | toasts (readable over any sky) |
| Focus | `COLOR_FOCUS` | `#FFFFFF` | 3 px focus ring |

**Measured contrast** (WCAG/XAG 102; verified in `tests/test_ui_v3_design_system.gd`):
body on card 15.2:1 · secondary on card 8.1:1 · inactive 4.8:1 (≥ 3) · CTA label on fill
5.2:1 (hover 4.5, pressed 7.0) · vermilion text on card 5.4:1 · success/warning/error/info on
card 9.3/9.6/5.6/10.0:1 · outline 3.1:1 (non-text ≥ 3) · focus ring vs card 16.7:1, vs CTA
5.2:1 · text on glass over a bright sky 10.9:1. *Baseline: white on the old CTA `#FF3D2E` was
3.5:1 (fail).*

## 3. Typography

Families: **Estedad** (OFL) Regular/Medium/Bold/Black for Persian; **Changa ExtraBold** (OFL)
for Latin instrument numerals only. Sizes are canvas px at 100 % UI scale (base canvas
1280×720). On a ~6" landscape phone one canvas px ≈ 0.55 pt, so the handheld default UI scale
(120 %) brings body text to ≈ 11 pt (Apple games guidance: aim 17 pt, never below 11 pt).

| Style | Variation | Font | Size | Line spacing |
|---|---|---|---|---|
| Display | `DisplayLabel` | Black | 44 | 0 |
| Headline | `HeadlineLabel` | Black | 30 | 0 |
| Title | `TitleLabel` | Bold | 22 | +2 |
| Section | `SectionLabel` | Bold | 19 | +2 |
| Body large | `BodyLargeLabel` | Medium | 19 | +6 |
| Body | `BodyLabel` / `BodyMutedLabel` | Medium | 17 | +6 (≈1.5× leading) |
| Label | `LabelStrong` / `ValueLabel` | Bold | 16 | +2 |
| Caption (minimum) | `CaptionLabel`, `OverlineLabel` | Medium/Bold | 15 | +3 |
| Numerals | `NumericLabel` | Changa XB | 22–60 | — |

Rules: never below 15 px; no negative tracking (Persian joins); every Persian label is
created through `UiTheme.label()` which forces an RTL paragraph and an RTL layout (Godot's
`auto` direction mis-ordered Persian sentences that start with a Latin word — audit A-04);
Latin runs (IP, version, key names) get their own LTR label via `UiTheme.ltr_label()`.
Digits: `UiTheme.fa_digits()/fa_int()/fa_int_grouped()/fa_float()/fa_percent()` (decimal «٫»,
thousands «٬», percent «٪»).

## 4. Spacing, layout, shape, elevation

- Spacing scale (4/8 grid): `SPACE_1..7` = 4, 8, 12, 16, 24, 32, 48. Safe inset 16 px.
- Sizes: `TOUCH_MIN` = 56 px (≈ 37 pt on a phone at 120 %), `CONTROL_HEIGHT_LG` = 64 px,
  driving pedals derived from the canvas (≈ 8–9 mm), icons 22–24 px.
- Shape scale: `RADIUS_XS/SM/MD/LG/XL/FULL` = 6, 10, 14, 20, 28, 999.
- Elevation: tonal surfaces first; shadows only for floating layers (cards 0, glass 24 px,
  sheets 32 px, dialogs 40 px) plus a scrim (`COLOR_SCRIM`, 72 %) behind modals.
- Adaptive layout: logical canvas = window ÷ UI scale. Layout classes in the showroom:
  LANDSCAPE (aspect ≥ 1.25), SQUARE (0.85–1.25), PORTRAIT (< 0.85); "narrow" < 980 px wide
  (icon-only app-bar buttons), "short" < 600 px tall (tighter dock, smaller display type).
  Settings rows reflow below 500 px panel width (sliders stack; switches stay inline).
- RTL rule: anchored containers stay LTR so anchors are literal; only text containers are RTL
  (v0.1-b1 put RTL on anchored nodes, which mirrored the showroom card and the pause drawer to
  the wrong side — audit A-10). Thumb controls are not mirrored (ergonomics).

## 5. Icons and assets

`UiIcon`: one family on a 24 px grid, 2 px round strokes, rendered from inline SVG to cached
white textures at 3× with mipmaps (crisp from phones to 4K) and tinted by the theme's
`icon_*_color` items. 46 glyphs (actions, devices, telemetry, pedals). RTL: `back` points
right, `forward` left; media `play` is never mirrored. No external icon assets.
Retired kits (kept on disk, unreferenced, export-excluded is optional): Softline UI Kit SVGs
and the Ville Seppänen dial PNGs (the dials printed «MPH» and a 9 000 rpm redline — audit A-07).

## 6. Motion

| Token | Duration | Use |
|---|---|---|
| `MOTION_FAST_MS` | 120 ms | state feedback (button press/hover, tab fade) |
| `MOTION_MEDIUM_MS` | 220 ms | sheets, drawer, dialogs, overlay rise |
| `MOTION_SLOW_MS` | 320 ms | screen entrances (menu intro, HUD intro) |

Easing: enter = quartic ease-out (≈ M3 emphasized-decelerate), exit = cubic ease-in.
Movement uses `Control.offset_transform_*` (Godot 4.7, visual-only) so containers and hit
areas never move. **Reduced motion** (Settings › دسترسی): `UiTheme.motion_sec()` returns 0 so
every movement lands instantly; opacity fades shrink to ≤ 90 ms (`fade_sec`); the showroom
turntable, idle camera tour and sweep light stop; button pops, photo flash and the damage
vignette pulse are off.

## 7. Components and states

| Component | Variation / class | States |
|---|---|---|
| Primary CTA | `PrimaryButton` | normal · hover · pressed · focus ring · disabled (graphite) |
| Secondary | `SecondaryButton` (outlined) | same |
| Low-emphasis | `GhostButton` | same |
| Destructive | `DangerButton` (outlined red) | same — never the filled CTA |
| Icon button | `IconButton` | same; label shown when wide, tooltip + accessibility name always |
| Tab / segment | `TabButton` (+ `SettingsPanel.Segmented`) | selected = vermilion outline + tint (distinct from focus) |
| Car card | `ChipButton` | selected / focus / hover |
| Switch | `CheckButton` (drawn track + knob) | on · off · disabled · focus |
| Slider | `HSlider` (vermilion fill, white knob with vermilion ring) | normal · highlight · disabled |
| Panels | `GlassPanel`, `CardPanel`, `SheetPanel`, `DialogPanel`, `HudPanel`, `ToastPanel` | — |
| Status chip | `VehicleHud._chip()` | tone + icon + text |
| Prompts | `InputPrompts.PromptChip`, `InputPrompts.Glyph` | follow the active device; hide when unbound |
| Overlays | `UiModalStack` | focus trap, Esc/B close, focus return |

Feedback rules: settings save automatically (debounced 350 ms) and show «ذخیره شد»; tool
actions toast their result (lights on/off, car reset, photo saved with file name); errors say
what happened and how to recover (LAN IP format, photo save failure). Consequential actions
(restart, return to showroom, quit) always confirm with a specific title, the consequence,
a specific action label, and focus on the safe choice.

## 8. Accessibility checklist (Xbox Accessibility Guidelines used as a review list — not a certification)

- XAG 101 text: 15 px minimum, body 17 px, UI scale 85–150 % (not the full 200 % — see
  limitations), headers stay distinct when scaled.
- XAG 102 contrast: all pairs above; HUD text sits on backplates; toasts on inverse surface.
- XAG 103 colour: semantic colours always paired with icon/label/shape (lamps fill when on,
  gear letter + colour, status chips with icons).
- XAG 112/113 navigation & focus: every screen focuses a control on open; modals trap focus;
  3 px white focus ring distinct from hover and selection; Esc/B always backs out; LB/RB/Q/E
  page tabs and cars spatially (left input → item on the left).
- XAG 114 context: structured help per device; settings carry descriptions; prompts match the
  active device; graphics tiers explain their cost.
- XAG 115 destructive actions: quit (menu + pause), restart and leave confirm first.
- XAG 117 distractions: reduced-motion option.
- Screen readers (Godot 4.7 AccessKit): controls carry `accessibility_name`/`description`.
