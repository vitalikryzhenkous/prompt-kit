#!/usr/bin/env bash
# Claude Code SessionEnd hook: removes this session's gauge state file, then runs every executable in
# ~/.config/prompt-kit/session-end.d/ (sorted; hook JSON on stdin, PROMPT_KIT_FINAL=1, 3 s timeout each, output ignored).
set -uo pipefail
here=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
# shellcheck disable=SC1091
. "$here/../../bin/compat.sh"
in=$(cat)
sid=$(jq -r '.session_id // empty' <<<"$in" 2>/dev/null | tr -cd 'A-Za-z0-9_-' | cut -c1-40)
[[ -n $sid ]] || exit 0
rm -f "${AGENT_STATUS_DIR:-$HOME/.cache/agent-status}/claude-code.$sid.json"
shopt -s nullglob
for f in "${PROMPT_KIT_CONFIG:-$HOME/.config/prompt-kit}"/session-end.d/*; do
  [[ -f $f && -x $f ]] && printf '%s' "$in" | PROMPT_KIT_FINAL=1 pk_timeout 3 "$f" >/dev/null 2>&1
done
exit 0
