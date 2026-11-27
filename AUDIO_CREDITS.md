# Kilometer 2 — Audio Sources, Licensing & Mastering Credits

All audio assets in Kilometer 2 are loudness-matched (`44.1 kHz Ogg Vorbis`, true-peak limited to `-1.5 dBFS` or lower) and routed through a 5-bus Godot 4.7 mixer (`Master` with HardLimiter → `Music`, `Vehicle`, `SFX`, `UI`).

## 1. Soundtrack Music (`assets/audio/music/`)
| File | Source / Title | Author | License | Mastering Notes |
| --- | --- | --- | --- | --- |
| `music_showroom_lounge.ogg` | *Offline (Pause / Car Customization Music)* — OpenGameArt | Cleyton Kauffman | **CC0 (Public Domain)** | 44.1 kHz stereo, seamless loop wrap, `-17.4 dBFS RMS`, `-1.9 dB` peak |
| `music_drive_velocity.ogg` | *Synthwave House Loop (114 BPM)* — OpenGameArt | Fupi | **CC0 (Public Domain)** | 44.1 kHz stereo, seamless loop wrap, `-16.3 dBFS RMS`, `-2.6 dB` peak |
| `music_drive_slipstream.ogg` | *Slipstream (Synthwave)* — OpenGameArt | cinameng (James Gargette) | **CC0 (Public Domain)** | 44.1 kHz stereo, seamless loop wrap, `-17.5 dBFS RMS`, `-4.9 dB` peak |

## 2. Per-Vehicle Core Engine Loops (`assets/audio/engine/`)
- `engine_sport_pride.ogg`, `engine_tara.ogg`, `engine_megan.ogg`, `engine_pride132.ogg`, `engine_quick.ogg`, `engine_samand.ogg`
- Six byte-distinct, loudness-matched (`-20 dBFS RMS`) engine recordings carried forward from K2-FINAL-003 (CC0 / CC-BY 3.0).

## 3. Vehicle Dynamics & World SFX (`assets/audio/sfx/`)
| File | Source | Author | License | Notes |
| --- | --- | --- | --- | --- |
| `sfx_engine_start.ogg` | *Car engine start 01* — OpenGameArt | looneybits | **CC0 (Public Domain)** | Trimmed, warm low-pass mastered, `-16.8 dBFS RMS` |
| `sfx_tire_screech.ogg` | *Car tire squeal skid loop* — OpenGameArt / Freesound | audible-edge (Tom Haigh), submitted by qubodup | **CC-BY 3.0** | Downsampled 96→44.1 kHz, tamed upper-harshness bandpass, seamless loop |
| `sfx_exhaust_sub.ogg` | Kilometer 2 DSP Synthesis | Kilometer 2 Audio Pipeline | **CC0 / Original** | 4-cylinder warm combustion sub-exhaust loop (integer cycles, zero-click) |
| `sfx_wind_road.ogg` | Kilometer 2 DSP Synthesis | Kilometer 2 Audio Pipeline | **CC0 / Original** | Stereo aerodynamic wind & asphalt road-roll bed |
| `sfx_gear_shift.ogg` | Kilometer 2 DSP Synthesis | Kilometer 2 Audio Pipeline | **CC0 / Original** | Mechanical linkage shift clunk + intake lift-off puff |
| `sfx_impact_thud.ogg` | Kilometer 2 DSP Synthesis | Kilometer 2 Audio Pipeline | **CC0 / Original** | Chassis low-end thud + damped body impact |
| `sfx_handbrake_click.ogg` | Kilometer 2 DSP Synthesis | Kilometer 2 Audio Pipeline | **CC0 / Original** | Tactile mechanical handbrake ratchet |

## 4. Menu & UI SFX (`assets/audio/ui/`)
- `ui_hover.ogg`, `ui_click.ogg`, `ui_tab.ogg`, `ui_confirm.ogg`, `ui_back.ogg`, `ui_toggle_on.ogg`, `ui_toggle_off.ogg`, `ui_car_switch.ogg`, `ui_start_drive.ogg`, `ui_pause_open.ogg`, `ui_pause_close.ogg`
- Layered from **Kenney — 51 UI Sound Effects** (OpenGameArt, **CC0**) organic click/switch transients combined with custom motorsport harmonic shaping (`-16.7` to `-24.2 dBFS RMS`).
