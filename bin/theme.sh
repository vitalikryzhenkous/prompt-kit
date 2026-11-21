#!/usr/bin/env bash
# theme.sh icon <module> <glyph | nf-<set>-<name> | U+XXXX>   — set the icon of a prompt module.
# modules: directory git_branch nodejs time username. Edits the format line of starship/starship.toml
# (override the file with THEME_TOML=...). Names resolve through Nerd Fonts glyphnames.json
# (pinned version + sha256, cached in ~/.cache/prompt-kit/).
set -euo pipefail
here=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
# shellcheck disable=SC1091
. "$here/bin/versions.env"
. "$here/bin/compat.sh"
toml=${THEME_TOML:-$here/starship/starship.toml}
usage() { echo "usage: theme.sh icon <directory|git_branch|nodejs|time|username> <glyph|nf-name|U+XXXX>
       theme.sh host-icon <glyph|nf-name|U+XXXX>   (icon of this node: ~/.config/prompt-kit/host.env)" >&2; exit 2; }
glyphnames() {
  local c=${XDG_CACHE_HOME:-$HOME/.cache}/prompt-kit/glyphnames.json
  if ! { [[ -f $c ]] && echo "$NERDFONTS_GLYPHNAMES_SHA256  $c" | pk_sha256_check >/dev/null 2>&1; }; then
    mkdir -p "$(dirname "$c")"; local t; t=$(mktemp "$c.XXXXXX")
    curl -fsSL "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/$NERDFONTS_VERSION/glyphnames.json" -o "$t" \
      && echo "$NERDFONTS_GLYPHNAMES_SHA256  $t" | pk_sha256_check >/dev/null || { rm -f "$t"; echo "glyphnames.json: download/sha256 failed" >&2; exit 1; }
    mv "$t" "$c"
  fi
  printf '%s' "$c"
}
cmd=${1:-}
if [[ $cmd == host-icon && $# -eq 2 ]]; then mod=host; arg=$2
elif [[ $cmd == icon && $# -eq 3 ]]; then mod=$2; arg=$3
else usage; fi
case $mod in host) ;; directory) var=path;; git_branch) var=branch;; nodejs) var=version;; time) var=time;; username) var=user;; *) usage;; esac
if [[ $arg =~ ^nf-[A-Za-z0-9]+-[A-Za-z0-9_]+$ ]]; then
  code=$(jq -r --arg k "${arg#nf-}" '.[$k].code // empty' "$(glyphnames)")
  [[ -n $code ]] || { echo "unknown Nerd Font name: $arg (glyphnames $NERDFONTS_VERSION)" >&2; exit 1; }
elif [[ $arg =~ ^[Uu]\+([0-9A-Fa-f]{4,6})$ ]]; then code=${BASH_REMATCH[1]}
elif [[ $(printf '%s' "$arg" | python3 -c 'import sys;print(len(sys.stdin.read()))') == 1 && $arg != [[:ascii:]] ]]; then
  code=$(printf '%s' "$arg" | python3 -c 'import sys;print("%x"%ord(sys.stdin.read()))')
else echo "icon must be one glyph, nf-<set>-<name> or U+XXXX" >&2; exit 2; fi
if [[ $mod == host ]]; then   # node icon: local file outside git, read by the shell hook block
  hf=${PROMPT_KIT_CONFIG:-$HOME/.config/prompt-kit}/host.env; mkdir -p "$(dirname "$hf")"
  tmp=$(mktemp "$hf.XXXXXX"); { [[ -f $hf ]] && grep -v '^PROMPT_KIT_HOST_ICON=' "$hf" || true; } > "$tmp"
  printf 'PROMPT_KIT_HOST_ICON=%b\n' "$(printf '\\U%08x' "0x$code")" >> "$tmp"; mv "$tmp" "$hf"
  echo "host icon: U+${code^^} -> $hf (open a new shell)"; exit 0
fi
python3 - "$toml" "$mod" "$var" "$code" <<'PY'
import re, sys
path, mod, var, code = sys.argv[1:]
icon = chr(int(code, 16))
s = open(path, encoding="utf-8").read()
m = re.search(r'(?ms)^\[%s\]\n.*?(?=^\[|\Z)' % re.escape(mod), s)
if not m: sys.exit("module [%s] not found in %s" % (mod, path))
sec = m.group(0)
new, n = re.subn(r'(?m)^(format = ".*?\[) +(?:[^\x00-\x7f]+ +)?(?=\$%s)' % var, lambda g: g.group(1) + " " + icon + " ", sec, count=1)
if n != 1: sys.exit("no `[ ... $%s` in the format of [%s]" % (var, mod))
open(path, "w", encoding="utf-8").write(s.replace(sec, new, 1))
print("%s: U+%X set" % (mod, ord(icon)))
PY
