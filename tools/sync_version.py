#!/usr/bin/env python3
"""Keep the build version in sync with scripts/ui/version_info.gd.

B9 fix: the version string used to live in three places (export preset,
main-menu pill, README) and had silently drifted. VersionInfo.BUILD is now
the only source; the menu reads it at runtime and this script pushes it into
export_presets.cfg (version/code + version/name) and the docs.

    python3 tools/sync_version.py [--check]

--check exits 1 when something is out of sync (usable in CI).
"""
from __future__ import annotations
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VERSION_GD = ROOT / "scripts/ui/version_info.gd"
PRESET = ROOT / "export_presets.cfg"
# CHANGELOG history is intentionally excluded: past entries must keep the version
# they were released under. Only the *current* version lives in VersionInfo.
DOC_FILES = [ROOT / "README.md", ROOT / "documentation/ARCHITECTURE.md"]


def read_version() -> tuple[str, str]:
    src = VERSION_GD.read_text(encoding="utf-8")
    base = re.search(r'const BASE := "([^"]+)"', src)
    track = re.search(r'const TRACK := "([^"]+)"', src)
    if not base or not track:
        raise SystemExit("version_info.gd: BASE/TRACK consts not found")
    build = f"{base.group(1)}-{track.group(1)}"
    code = re.search(r"const CODE := (\d+)", src)
    if not code:
        raise SystemExit("version_info.gd: CODE const not found")
    return build, code.group(1)


def main() -> int:
    build, code = read_version()
    check = "--check" in sys.argv
    changed: list[str] = []

    preset = PRESET.read_text(encoding="utf-8")
    healed = re.sub(r'version/code=\d+', f"version/code={code}", preset)
    healed = re.sub(r'version/name="[^"]*"', f'version/name="{build}"', healed)
    if healed != preset:
        changed.append(str(PRESET.relative_to(ROOT)))
        if not check:
            PRESET.write_text(healed, encoding="utf-8")

    for doc in DOC_FILES:
        if not doc.exists():
            continue
        text = doc.read_text(encoding="utf-8")
        healed = re.sub(r'\b\d+\.\d+\.\d+-b\d+\b', build, text)
        if healed != text:
            changed.append(str(doc.relative_to(ROOT)))
            if not check:
                doc.write_text(healed, encoding="utf-8")

    if check:
        if changed:
            print("OUT OF SYNC: " + ", ".join(changed) + f" (expected {build})")
            return 1
        print(f"OK: everything reports {build}")
        return 0
    print(f"version {build} (code {code}); updated: {', '.join(changed) if changed else 'nothing'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
