#!/usr/bin/env bash
# prompt-kit uninstaller. Undoes what bin/install.sh did, using its backups (`<file>.bak.<timestamp>`).
# Flags: --dry-run. Files other tools also edit (~/.claude/settings.json, ~/.bashrc, Windows Terminal settings) are
# changed surgically (only our entries removed) instead of restoring a whole old backup over later edits;
# the oldest backup stays next to the file if you prefer to restore it by hand.
# Never removed: ~/.local/bin/starship, ~/.config/prompt-kit/ (your config), the Windows font.
set -uo pipefail
REPO=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
DRY=0; [[ ${1:-} == --dry-run ]] && DRY=1
[[ $# -le 1 && ( $# -eq 0 || $DRY == 1 ) ]] || { echo "usage: uninstall.sh [--dry-run]" >&2; exit 2; }
TS=$(date +%Y%m%d-%H%M%S)
say() { echo "• $*"; }
run() { if (( DRY )); then say "WOULD: $*"; else "$@"; fi; }
bak() { [[ -e $1 ]] && run cp -P "$1" "$1.bak.uninstall.$TS"; }
oldest_bak() { ls -1 "$1".bak.2* 2>/dev/null | head -1; }
command -v jq >/dev/null || { echo "missing: jq" >&2; exit 1; }
say "mode: $([[ $DRY == 1 ]] && echo DRY-RUN || echo APPLY); repo=$REPO"

# 1. starship config symlink -> restore the pre-install file if there was one
cfg=$HOME/.config/starship.toml
if [[ -L $cfg && $(readlink "$cfg") == "$REPO/starship/starship.toml" ]]; then
  b=$(oldest_bak "$cfg")
  run rm -f "$cfg"
  if [[ -n $b ]]; then run cp -P "$b" "$cfg"; say "restored $cfg from $b"; else say "removed $cfg (no earlier backup)"; fi
else say "starship.toml is not our symlink: left alone"; fi

# 2. agent reader symlink
rd=$HOME/.local/bin/prompt-kit-agent-read
if [[ -L $rd && $(readlink "$rd") == "$REPO/bin/agent-read.sh" ]]; then run rm -f "$rd"; say "removed $rd"; else say "agent reader link not ours: left alone"; fi

# 3. .bashrc / .zshrc: drop our 3-line block (+ the blank line before it), only if it is exactly what install wrote
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [[ -f $rc ]] || continue
  n=$(grep -n '^# prompt-kit$' "$rc" | head -1 | cut -d: -f1)
  [[ -n $n ]] || continue
  if [[ $(sed -n "$((n+1))p" "$rc") == 'case ":$PATH:" in'* && $(sed -n "$((n+2))p" "$rc") == 'eval "$(starship init '* ]]; then
    bak "$rc"
    s=$n; [[ -z $(sed -n "$((n-1))p" "$rc") ]] && s=$((n-1))
    run sed -i "${s},$((n+2))d" "$rc"; say "removed prompt-kit block from $rc"
  else say "⚠ $rc: '# prompt-kit' block was edited: remove it by hand"; fi
done

# 4. Claude Code settings: our hook and statusLine only
S=$HOME/.claude/settings.json
if [[ -f $S ]] && jq -e . "$S" >/dev/null 2>&1; then
  ours=$REPO/adapters/claude-code/statusline.sh; hk=$REPO/adapters/claude-code/session-end.sh
  old=$HOME/.config/prompt-kit/inner-statusline
  bak "$S"
  if (( DRY )); then say "WOULD: remove SessionEnd hook $hk and statusLine $ours from $S (restore old statusLine from $old if present)"
  else
    out=$(jq --arg h "$hk" --arg c "$ours" --arg old "$( [[ -s $old ]] && cat "$old" || true )" '
      (if .hooks.SessionEnd then .hooks.SessionEnd |= map(.hooks |= map(select(.command != $h))) | .hooks.SessionEnd |= map(select(.hooks|length>0)) else . end)
      | (if (.hooks.SessionEnd // [1]|length)==0 then del(.hooks.SessionEnd) else . end)
      | (if .statusLine.command == $c then (if $old != "" then .statusLine.command = $old else del(.statusLine) end) else . end)' "$S") \
      && cat <<<"$out" > "$S" && say "cleaned $S"
  fi
else say "no usable $S: skipped"; fi

# 5. Windows Terminal font set for this distro
wt=$(ls /mnt/c/Users/*/AppData/Local/Packages/Microsoft.WindowsTerminal*/LocalState/settings.json 2>/dev/null | head -1 || true)
if [[ -n $wt && -n ${WSL_DISTRO_NAME:-} ]] && jq -e . "$wt" >/dev/null 2>&1; then
  sel='.profiles.list[]? | select(.source=="Windows.Terminal.Wsl" and .name==$d and .font.face=="JetBrainsMono Nerd Font")'
  if [[ $(jq --arg d "$WSL_DISTRO_NAME" "[$sel]|length" "$wt") == 1 ]]; then
    bak "$wt"
    if (( DRY )); then say "WOULD: remove font.face from the '$WSL_DISTRO_NAME' profile in Windows Terminal"
    else out=$(jq --arg d "$WSL_DISTRO_NAME" "($sel | .font) |= del(.face) | (.profiles.list[]? | select(.font == {}) ) |= del(.font)" "$wt") && cat <<<"$out" > "$wt" && say "removed font.face for '$WSL_DISTRO_NAME'"; fi
  fi
fi

# 6. per-session state
for f in "$HOME"/.cache/agent-status/claude-code.*.json "$HOME/.cache/agent-status/claude-code.json"; do [[ -e $f ]] && run rm -f "$f"; done
say "left in place: ~/.local/bin/starship, ~/.config/prompt-kit/ (agent.env, statusline.env, segments.d), the Windows font, *.bak.* files"
(( DRY )) && echo "== dry-run only, nothing written" || echo "== done: open a new shell"
