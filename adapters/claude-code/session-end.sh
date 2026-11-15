#!/usr/bin/env bash
# Claude Code SessionEnd hook: removes this session's gauge state file, then sends the final state to the
# uptime board (if the segment exists), bypassing its 30 s throttle. stdin: hook JSON.
set -uo pipefail
in=$(cat)
sid=$(jq -r '.session_id // empty' <<<"$in" 2>/dev/null | tr -cd 'A-Za-z0-9_-' | cut -c1-40)
[[ -n $sid ]] || exit 0
rm -f "${AGENT_STATUS_DIR:-$HOME/.cache/agent-status}/claude-code.$sid.json"
rep=${PROMPT_KIT_CONFIG:-$HOME/.config/prompt-kit}/segments.d/90-uptime-report.sh
[[ -x $rep ]] && UPTIME_REPORT_MIN_S=0 UPTIME_REPORT_FINAL=1 "$rep" <<<"$in" >/dev/null 2>&1
exit 0
