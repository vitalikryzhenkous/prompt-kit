#!/usr/bin/env bash
# Claude Code SessionEnd hook: removes this session's gauge state file. stdin: hook JSON.
set -euo pipefail
sid=$(jq -r '.session_id // empty' | tr -cd 'A-Za-z0-9_-' | cut -c1-40)
[[ -n $sid ]] && rm -f "${AGENT_STATUS_DIR:-$HOME/.cache/agent-status}/claude-code.$sid.json"
exit 0
