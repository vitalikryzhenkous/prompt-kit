#!/usr/bin/env bash
# Claude Code statusLine hook: reads session JSON on stdin, writes the agent state file,
# prints one status line. If ~/.config/prompt-kit/inner-statusline exists, its output comes first.
set -euo pipefail
umask 077
in=$(cat)
dir=${AGENT_STATUS_DIR:-$HOME/.cache/agent-status}
mkdir -p "$dir"; chmod 700 "$dir"
# Claude Code's own pid: nearest ancestor named claude (fallback: parent). Used by the reader for liveness.
pid=$PPID; q=$$
for _ in 1 2 3 4 5 6; do q=$(awk '{print $4}' "/proc/$q/stat" 2>/dev/null) || break; [[ $q =~ ^[0-9]+$ && $q -gt 1 ]] || break
  [[ $(cat "/proc/$q/comm" 2>/dev/null) == claude* ]] && { pid=$q; break; }; done
sid=$(printf '%s' "$in" | jq -r '.session_id // empty' | tr -cd 'A-Za-z0-9_-' | cut -c1-40)
# drop state files of dead sessions (only <provider>.<session>.json, never raw)
for f in "$dir"/claude-code.*.json; do [[ $f == *.raw.json ]] && continue
  fp=$(jq -r '.pid // empty' "$f" 2>/dev/null || true); [[ $fp =~ ^[0-9]+$ ]] && kill -0 "$fp" 2>/dev/null || rm -f "$f"; done
raw=$dir/claude-code.raw.json
[[ -e $raw ]] || printf '%s' "$in" > "$raw"
state=$(printf '%s' "$in" | jq -c --arg now "$(date +%s)" --argjson pid "$pid" '
  .context_window as $c | {
    provider: "claude-code",
    model: ((.model.display_name // .model.id // "?") | ascii_downcase),
    ctx_used_pct: ($c.used_percentage | if . == null then null else round end),
    ctx_left_tokens: (if $c.remaining_percentage != null and $c.context_window_size != null
                      then ($c.context_window_size * $c.remaining_percentage / 100 | floor) else null end),
    ctx_size: $c.context_window_size,
    session: ((.session_id // "") | .[0:4]),
    cwd: (.workspace.current_dir // .cwd // ""),
    pid: $pid,
    ts: ($now | tonumber)
  }' 2>/dev/null) || state=
if [[ -n $state && -n $sid ]]; then
  tmp=$(mktemp "$dir/.claude-code.XXXXXX")
  printf '%s\n' "$state" > "$tmp"; mv "$tmp" "$dir/claude-code.$sid.json"
fi
out=
inner=$HOME/.config/prompt-kit/inner-statusline
if [[ -s $inner ]]; then out=$(printf '%s' "$in" | sh -c "$(cat "$inner")" 2>/dev/null || true); fi
gauge=
if [[ -n $state ]]; then
  pct=$(printf '%s' "$state" | jq -r '.ctx_used_pct // empty')
  [[ -n $pct ]] && gauge="◰ ${pct}%"
fi
printf '%s%s\n' "$out" "${gauge:+ $gauge}"
