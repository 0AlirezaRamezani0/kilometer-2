class_name VersionInfo
extends RefCounted

## Single source of truth for the build version.
## Before this file the version string was duplicated in three places
## (export_presets.cfg, the main-menu pill and the README), and they had
## already drifted apart: the menu said 4.2.0-b7 while the docs said 4.0.0.
## Change `BUILD` here, then run `python3 tools/sync_version.py` from the
## project root to push the value into export_presets.cfg and the docs.

const BASE := "v0.3"
const TRACK := "b2-android-lan"
## Android/Play versionCode — must only ever increase.
## v0.1-b2 was an undelivered redesign branch (session 1); b3 skips to code 3
## so the versionCode stays monotonic even if a b2 build was ever installed.
## v0.1-b4 (desert-garage showroom stage) used code 4; v0.1-b5 (optimised
## garage asset, wheel-seating fix) used code 5; v0.2-b1 (desert circuit map
## replaces the proving ground, identity-v2 loading screen mounted) uses code 6.
## v0.2-b2 (map + collision rework: barrier-aware plan, real overpass elevation, invisible
## walls removed, 3 s simulated loading dwell) uses code 7.
## v0.2-b2-racetrack-obj (the delivered desert circuit replaced by racetrack.obj; centreline,
## collision and surface regenerated from that mesh) uses code 8.
## v0.2-b4-brand-lan (brand loading lockup, K2 app icon and boot splash, LAN host discovery)
## used code 10. v0.2-b5-logo-shoulders (loading screen back to the studio car render with the
## KILOMETER logotype only, pale shoulder ribbons dropped from the drawn deck, start gantry
## rebuilt so the countdown lamps no longer float) uses code 11.
## v0.2-b6-clean-road (guard rails no longer drawn — the invisible walls stay — and an opaque
## brand-black launcher icon so the Android launch splash can never show a white card) uses code 12.
## v0.3-b1-android-lan (Android LAN multiplayer fixes: Wi-Fi/multicast permissions, interface-aware
## LAN IP selection, port 42425 discovery/advertise fix, periodic beacons & hotspot subnet/gateway
## targets, Persian-numeral IP normalization, SceneTransition queuing, and LAN sync freeze fix)
## used code 13.
## v0.3-b2-android-lan (Build 2 Android LAN fixes: standard boolean manifest permissions for
## non-Gradle export, ENet explicit IPv4 0.0.0.0 bind & reconnect slots, /24 unicast discovery
## sweep bypassing Wi-Fi broadcast filters, reliable _ack_vehicle handshake eliminating async
## scene-load sync deadlock, Basis orthonormalization, and live lobby IP refresh) uses code 14.
const CODE := 14
const BUILD := BASE + "-" + TRACK
const DISPLAY := "K2 · " + BUILD
