#!/usr/bin/env bash
# check-icons.sh [starship.toml] — every icon module must have a glyph in its format (`[ <glyph> $var`).
# Guards against the item-4 regression (icons silently lost). Exit 1 and list the modules that lack one.
set -euo pipefail
here=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
exec python3 - "${1:-$here/starship/starship.toml}" <<'PY'
import re, sys
mods = {"directory": "path", "git_branch": "branch", "nodejs": "version", "time": "time", "username": "user"}
s = open(sys.argv[1], encoding="utf-8").read()
bad = []
for mod, var in mods.items():
    m = re.search(r'(?ms)^\[%s\]\n.*?(?=^\[|\Z)' % mod, s)
    f = re.search(r'(?m)^format = "(.*)"$', m.group(0)) if m else None
    if not f or not re.search(r'\[ +[^\x00-\x7f]+ +\$%s\b' % var, f.group(1)):
        bad.append(mod)
if bad:
    print("no glyph in format of: " + ", ".join(bad)); sys.exit(1)
print("glyphs ok: " + ", ".join(mods))
PY
