#!/usr/bin/env bash
# check-hook.sh — syntax-check the rc block for every shell that is installed (bash -n, zsh -n).
# A shell that is not installed is reported as SKIP, never as PASS.
set -uo pipefail
here=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
rc=0
for sh in bash zsh; do
  if ! command -v "$sh" >/dev/null 2>&1; then echo "SKIP  $sh hook: $sh not installed (not verified)"; continue; fi
  "$here/hook-block.sh" "$sh" > "$tmp/$sh.rc" || { echo "FAIL  $sh hook: cannot generate"; rc=1; continue; }
  if "$sh" -n "$tmp/$sh.rc" 2>"$tmp/err"; then echo "PASS  $sh hook syntax (-n)"; else echo "FAIL  $sh hook syntax: $(head -1 "$tmp/err")"; rc=1; fi
  grep -q "starship init $sh" "$tmp/$sh.rc" || { echo "FAIL  $sh hook: wrong init line"; rc=1; }
done
exit $rc
