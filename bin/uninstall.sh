#!/usr/bin/env bash
# prompt-kit uninstaller. Undoes what bin/install.sh did.
# Flags: --dry-run. Files other tools also edit (~/.claude/settings.json, rc files, Windows Terminal settings) are
# changed surgically (only our entries removed) instead of restoring a whole old backup over later edits.
# The pre-install ~/.config/starship.toml is restored from the backup recorded in ~/.config/prompt-kit/install-manifest.
# Never removed: ~/.local/bin/starship, ~/.config/prompt-kit/ (your config), the Windows font, *.bak.* files.
set -uo pipefail
REPO=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
DRY=0; [[ ${1:-} == --dry-run ]] && DRY=1
[[ $# -le 1 && ( $# -eq 0 || $DRY == 1 ) ]] || { echo "usage: uninstall.sh [--dry-run]" >&2; exit 2; }
TS=$(date +%Y%m%d-%H%M%S)
# shellcheck disable=SC1091
. "$REPO/bin/deps.sh"
say() { echo "• $*"; }
run() { if (( DRY )); then say "WOULD: $*"; else "$@"; fi; }
bak() { [[ -e $1 ]] && run cp -P "$1" "$1.bak.uninstall.$TS"; }
command -v jq >/dev/null || { echo "missing: jq" >&2; exit 1; }
say "mode: $([[ $DRY == 1 ]] && echo DRY-RUN || echo APPLY); repo=$REPO"
manifest=$HOME/.config/prompt-kit/install-manifest

# 1. starship config symlink -> restore the pre-install file recorded at install time (if there was one)
cfg=$HOME/.config/starship.toml
if [[ -L $cfg && $(readlink "$cfg") == "$REPO/starship/starship.toml" ]]; then
  b=$(sed -n 's/^starship.toml=//p' "$manifest" 2>/dev/null | head -1)
  run rm -f "$cfg"
  if [[ -n $b && $b != NONE && ( -e $b || -L $b ) ]]; then run cp -P "$b" "$cfg"; say "restored $cfg from $b"
  else say "removed $cfg (no pre-install file recorded)"; fi
else say "starship.toml is not our symlink: left alone"; fi

# 2. agent reader symlink
rd=$HOME/.local/bin/prompt-kit-agent-read
if [[ -L $rd && $(readlink "$rd") == "$REPO/bin/agent-read.sh" ]]; then run rm -f "$rd"; say "removed $rd"; else say "agent reader link not ours: left alone"; fi

# 3. rc files: drop our block, only if it matches bin/hook-block.sh exactly (rewrites through cat, so a symlinked rc stays a symlink)
for kind in bash zsh; do
  rc=$HOME/.${kind}rc
  [[ -f $rc ]] || continue
  cnt=$(grep -c '^# prompt-kit$' "$rc")
  (( cnt >= 1 )) || continue
  (( cnt == 1 )) || { say "⚠ $rc has $cnt '# prompt-kit' blocks: remove them by hand"; continue; }
  n=$(grep -n '^# prompt-kit$' "$rc" | cut -d: -f1)
  want=$("$REPO/bin/hook-block.sh" "$kind" | sed -n '3,4p')
  have=$(sed -n "$((n+1)),$((n+2))p" "$rc")
  if [[ $want == "$have" ]]; then
    bak "$rc"
    s=$n; [[ $n -gt 1 && -z $(sed -n "$((n-1))p" "$rc") ]] && s=$((n-1))
    if (( DRY )); then say "WOULD: remove lines $s-$((n+2)) (the prompt-kit block) from $rc"
    else sed "${s},$((n+2))d" "$rc" | pk_put "$rc" && say "removed prompt-kit block from $rc"; fi
  else say "⚠ $rc: the '# prompt-kit' block was edited: remove it by hand"; fi
done

# 4. Claude Code settings: our hook and statusLine only
S=$HOME/.claude/settings.json
if [[ -f $S ]] && jq -e . "$S" >/dev/null 2>&1; then
  ours=$REPO/adapters/claude-code/statusline.sh; hk=$REPO/adapters/claude-code/session-end.sh
  old=$HOME/.config/prompt-kit/inner-statusline
  bak "$S"
  if (( DRY )); then say "WOULD: remove SessionEnd hook $hk and statusLine $ours from $S (restore old statusLine from $old if present)"
  else
    # entries without a .hooks array are somebody else's: keep them untouched
    if out=$(jq --arg h "$hk" --arg c "$ours" --arg old "$( [[ -s $old ]] && cat "$old" || true )" '
      (if (.hooks.SessionEnd | type) == "array" then
         .hooks.SessionEnd |= (map(if (.hooks | type) == "array" then .hooks |= map(select(.command != $h)) else . end)
                               | map(select((.hooks | type) != "array" or (.hooks | length) > 0)))
       else . end)
      | (if (.hooks.SessionEnd | type) == "array" and (.hooks.SessionEnd | length) == 0 then del(.hooks.SessionEnd) else . end)
      | (if .statusLine.command == $c then (if $old != "" then .statusLine.command = $old else del(.statusLine) end) else . end)' "$S"); then
      pk_put "$S" <<<"$out" && say "cleaned $S"
    else say "⚠ jq failed: $S left untouched (backup: $S.bak.uninstall.$TS)"; fi
  fi
else say "no usable $S: skipped"; fi

# 5. Windows Terminal font set for this distro (settings of the current Windows user only)
wt=$(pk_wt_settings)
if [[ -n $wt && -n ${WSL_DISTRO_NAME:-} ]] && jq -e . "$wt" >/dev/null 2>&1; then
  sel='.profiles.list[]? | select(.source=="Windows.Terminal.Wsl" and .name==$d and .font.face=="JetBrainsMono Nerd Font")'
  if [[ $(jq --arg d "$WSL_DISTRO_NAME" "[$sel]|length" "$wt") == 1 ]]; then
    bak "$wt"
    if (( DRY )); then say "WOULD: remove font.face from the '$WSL_DISTRO_NAME' profile in Windows Terminal"
    elif out=$(jq --arg d "$WSL_DISTRO_NAME" "($sel | .font) |= del(.face) | (.profiles.list[]? | select(.font == {}) ) |= del(.font)" "$wt"); then
      pk_put "$wt" <<<"$out" && say "removed font.face for '$WSL_DISTRO_NAME'"
    else say "⚠ jq failed: Windows Terminal settings left untouched"; fi
  fi
fi

# 6. per-session state
for f in "$HOME"/.cache/agent-status/claude-code.*.json "$HOME/.cache/agent-status/claude-code.json"; do [[ -e $f ]] && run rm -f "$f"; done
say "left in place: ~/.local/bin/starship, ~/.config/prompt-kit/ (agent.env, statusline.env, segments.d), the Windows font, *.bak.* files"
(( DRY )) && echo "== dry-run only, nothing written" || echo "== done: open a new shell"
