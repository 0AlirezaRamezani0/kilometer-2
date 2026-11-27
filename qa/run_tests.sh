#!/usr/bin/env bash
# Kilometer 2 — headless test runner with summary.
# Usage:
#   GODOT_BIN=/path/to/godot bash qa/run_tests.sh          # all suites
#   bash qa/run_tests.sh -k physics                        # only suites matching "physics"
#   bash qa/run_tests.sh --import                          # (re)import project first
set -uo pipefail

GODOT_BIN="${GODOT_BIN:-${GODOT_PATH:-godot}}"
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
FILTER=""
DO_IMPORT=0

while [ $# -gt 0 ]; do
	case "$1" in
		-k|--filter) FILTER="${2:-}"; shift 2 ;;
		--import) DO_IMPORT=1; shift ;;
		-h|--help) sed -n '2,8p' "${BASH_SOURCE[0]}"; exit 0 ;;
		*) echo "unknown argument: $1" >&2; exit 2 ;;
	esac
done

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
	echo "FAIL: Godot binary not found ('$GODOT_BIN'). Set GODOT_BIN." >&2
	exit 2
fi
echo "Godot: $("$GODOT_BIN" --version 2>/dev/null | tail -1)"

cd "$PROJECT_DIR" || exit 2

if [ "$DO_IMPORT" = "1" ] || [ ! -d .godot ]; then
	echo "== import (cold cache: a transient Estedad font error on the first pass is expected) =="
	"$GODOT_BIN" --headless --path . --import >/tmp/k2_import.log 2>&1
	echo "   import exit=$?  errors=$(grep -c '^ERROR' /tmp/k2_import.log)"
fi

log=/tmp/k2_tests.log
: > "$log"
total_pass=0; total_fail=0; bad_suites=0; ran=0
printf '\n%-42s %6s %6s %6s\n' "SUITE" "PASS" "FAIL" "EXIT"
printf '%s\n' "---------------------------------------------------------------"

for t in tests/test_*.gd; do
	[ -n "$FILTER" ] && case "$t" in *"$FILTER"*) ;; *) continue ;; esac
	ran=$((ran+1))
	out=$("$GODOT_BIN" --headless --path . --script "res://$t" 2>&1); code=$?
	printf '%s\n' "### $t" "$out" >> "$log"
	p=$(printf '%s\n' "$out" | grep -c '\[PASS\]')
	f=$(printf '%s\n' "$out" | grep -c '\[FAIL\]')
	script_err=$(printf '%s\n' "$out" | grep -c 'SCRIPT ERROR')
	total_pass=$((total_pass+p)); total_fail=$((total_fail+f))
	status="ok"
	if [ "$f" -gt 0 ] || [ "$code" -ne 0 ] || [ "$script_err" -gt 0 ]; then bad_suites=$((bad_suites+1)); status="FAIL"; fi
	printf '%-42s %6s %6s %6s  %s\n' "$(basename "$t")" "$p" "$f" "$code" "$status"
done

printf '%s\n' "---------------------------------------------------------------"
printf '%-42s %6s %6s\n' "TOTAL ($ran suites)" "$total_pass" "$total_fail"
echo "full log: $log"
if [ "$bad_suites" -gt 0 ]; then
	echo "RESULT: FAIL ($bad_suites suite(s) with failures or script errors)"
	exit 1
fi
echo "RESULT: all green"
