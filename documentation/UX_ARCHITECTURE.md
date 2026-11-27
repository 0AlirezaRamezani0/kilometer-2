# Kilometer 2 — UX Architecture (v0.1-b3)

## 1. Journey and navigation map

```
Launch ─► Showroom (main menu) ──[شروع رانندگی]──► loading caption ─► Driving (HUD)
             │  ├─ Settings (modal) ── reset confirm                    │
             │  ├─ Help (modal: controls per device + credits)          ├─ Tools sheet ─► photo mode / replay / ghost / reset / lights
             │  ├─ Quit confirm ─► exit                                 ├─ Quick settings sheet ─► «همهٔ تنظیمات» (pause › settings)
             │  └─[بازی شبکه‌ای]─► LAN lobby ─► LAN game (same HUD)     └─ Pause drawer
             │                        └─ Esc/B/«بازگشت» ─► Showroom           ├─ Resume / Reset car / Settings (in drawer)
             └◄──────────────── confirm «بازگشت به نمایشگاه» ◄──────────────├─ Restart (confirm)
                                                                             └─ Quit (confirm)
```

Back behaviour is uniform: **Esc / B closes the top overlay**; in the showroom with nothing
open, Esc asks to quit; in driving, only the pause action (Esc / P / Start) pauses — B stays
the handbrake. Every overlay restores focus to the control that opened it.

Input methods: keyboard + mouse (desktop), gamepad (XInput-style mapping in `project.godot`),
multi-touch (Android). Prompts switch automatically with the last device used.

## 2. Screens

### Showroom (main menu) — `scripts/ui/main_menu.gd`
- **Purpose / task:** choose a car and start driving (or open LAN).
- **Key info:** car name, model, counter, honest specs (top speed, engine force, weight as
  fractions of the fleet maximum). **Key actions:** «شروع رانندگی» (the only filled CTA),
  «بازی شبکه‌ای», car selector, settings / help / quit.
- **Entry/exit:** app start, return from driving or LAN. Exit to driving, LAN, or quit (confirm).
- **States:** focus/hover/pressed/selected on cards and buttons; disabled CTA after start
  (prevents double scene change); loading caption during the transition.
- **Input:** ← / → (from the CTA) or LB/RB/Q/E switch cars spatially (RTL: left = next);
  cards are focusable and selection follows focus; drag rotates the car; Enter/A starts.
- **Responsive:** hero card on the start side (landscape/square) or a full-width band
  (portrait); app-bar buttons become icon-only below 980 px; dock becomes CTA-above-grid in
  portrait; card labels pick the longest format that fits all six; the camera frames the car
  in the free area with view offsets.
- **Accessibility:** single CTA, ≥ 56 px targets, prompts for the active device, reduced
  motion stops the turntable/tour/sweep, overlays trap focus.

### Settings — `scripts/ui/settings_panel.gd` (menu modal and pause drawer)
- **Tabs:** نمایش · صدا · دوربین · کنترل‌ها · دسترسی. Rows = title + description + control
  + value (Persian digits with units).
- **Behaviour:** live apply to the changed domain only; debounced save (350 ms) with a
  «ذخیره شد» chip; reset to defaults behind a confirmation; UI scale applies on release so the
  layout never jumps under the finger; fullscreen hidden on mobile.
- **Input:** tabs by LB/RB/Q/E; Esc/B closes (or closes the reset confirmation first).
- **Responsive:** 5-column tabs → 3+2 grid; rows single-line → stacked below 500 px.

### Help — modal in the showroom
- Device tabs (keyboard / gamepad / touch, defaulting to the active device), one row per
  action with real glyphs from `InputPrompts`, then «دربارهٔ بازی و مجوزها» (version, engine,
  fonts, vehicle-model notice).

### Driving HUD — `scripts/ui/vehicle_hud.gd`
- **Purpose:** drive; read speed/gear/rpm at a glance; reach tools without clutter.
- **Top:** vehicle chip (start) · session timer · contextual chips (slippery surface,
  damage, ghost delta, dev FPS) · tools and pause buttons (end, neutral).
- **Bottom:** steering zone (buttons / wheel / analog bar) · instrument cluster (tach, gear,
  lamps, pedal bars, speedometer with digital readout) · pedals. Thumb zones are not mirrored.
- **Overlays:** tools action sheet (choosing a tool performs it and closes); quick-settings
  side sheet; pause drawer (start side) with settings view; confirmation dialog; toasts on the
  inverse surface; photo-mode prompt bar.
- **Feedback:** toasts for lights, reset, replay start/end, photo saved (file name) or failed
  (with recovery hint); impact chip + optional vignette; damage chip appears once damaged.
- **Gamepad:** binding strip for 8 s when a pad becomes active; A in photo mode captures.
- **Responsive:** control sizes derive from the canvas (B9 rules kept); the cluster lifts above
  the controls when the bottom row is too narrow; app-bar labels hide below 1000 px.

### LAN lobby — `scripts/multiplayer/lan_lobby.gd`
- Host card (own IP in large LTR digits, create, cancel) and guest card (IP field with
  validation and error text, join). Status chip = tone + icon + text with a spinner while
  waiting/connecting. Buttons enable only when they apply. Focus starts on «ساخت اتاق»;
  Esc/B or «بازگشت» returns to the showroom.

### Transitions — `scripts/ui/scene_transition.gd` (autoload)
- Fade through the background colour with a caption («در حال آماده‌سازی پیست — <car>»),
  instant under reduced motion. The LAN game scene opens directly so the two-device handshake
  timing is unchanged.

## 3. Screens not present (by design)
Loading/results/game-over, onboarding, inventory, map and missions do not exist in this game
and were not invented. The "Garage" tab of v0.1-b1 was removed: it was a fake navigation
target (the showroom *is* the garage).
