#!/usr/bin/env bash
# Claude Code statusLine hook: reads session JSON on stdin, writes the agent state file,
# prints one status line. If ~/.config/prompt-kit/inner-statusline exists, its output comes first.
set -euo pipefail
umask 077
in=$(cat)
dir=${AGENT_STATUS_DIR:-$HOME/.cache/agent-status}
mkdir -p "$dir"; chmod 700 "$dir"
raw=$dir/claude-code.raw.json
[[ -e $raw ]] || printf '%s' "$in" > "$raw"
state=$(printf '%s' "$in" | jq -c --arg now "$(date +%s)" '
  .context_window as $c | {
    provider: "claude-code",
    model: ((.model.display_name // .model.id // "?") | ascii_downcase),
    ctx_used_pct: ($c.used_percentage | if . == null then null else round end),
    ctx_left_tokens: (if $c.remaining_percentage != null and $c.context_window_size != null
                      then ($c.context_window_size * $c.remaining_percentage / 100 | floor) else null end),
    ctx_size: $c.context_window_size,
    session: ((.session_id // "") | .[0:4]),
    cwd_base: ((.workspace.current_dir // .cwd // "") | split("/") | last),
    ts: ($now | tonumber)
  }' 2>/dev/null) || state=
if [[ -n $state ]]; then
  tmp=$(mktemp "$dir/.claude-code.XXXXXX")
  printf '%s\n' "$state" > "$tmp"; mv "$tmp" "$dir/claude-code.json"
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
