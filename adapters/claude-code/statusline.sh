#!/usr/bin/env bash
# Claude Code statusLine hook: reads session JSON on stdin, writes the agent state file,
# prints one status line built from segments (config: ~/.config/prompt-kit/statusline.env, docs/wiki/Agents.md).
set -uo pipefail   # no -e: a status line must never fail
umask 077
in=$(cat)
here=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
cfgdir=${PROMPT_KIT_CONFIG:-$HOME/.config/prompt-kit}
# shellcheck disable=SC1091
. "$here/../../bin/env-load.sh"
pk_load_env "$cfgdir/statusline.env" SEGMENTS SEP INNER_COMMAND
pk_load_env "$cfgdir/agent.env" AGENT_COMPACT_AT STATUSLINE_SEGMENTS
[[ ${AGENT_COMPACT_AT:-95} =~ ^[0-9]+$ ]] || AGENT_COMPACT_AT=95
dir=${AGENT_STATUS_DIR:-$HOME/.cache/agent-status}
mkdir -p "$dir"; chmod 700 "$dir"
# Claude Code's own pid: nearest ancestor named claude (fallback: parent). Used by the reader for liveness.
pid=$PPID; q=$$
for _ in 1 2 3 4 5 6; do q=$(awk '{print $4}' "/proc/$q/stat" 2>/dev/null) || break; [[ $q =~ ^[0-9]+$ && $q -gt 1 ]] || break
  [[ $(cat "/proc/$q/comm" 2>/dev/null) == claude* ]] && { pid=$q; break; }; done
sid=$(printf '%s' "$in" | jq -r '.session_id // empty' 2>/dev/null | tr -cd 'A-Za-z0-9_-' | cut -c1-40)
# drop state files of dead sessions (only <provider>.<session>.json, never raw)
for f in "$dir"/claude-code.*.json; do [[ $f == *.raw.json ]] && continue
  fp=$(jq -r '.pid // empty' "$f" 2>/dev/null || true); [[ $fp =~ ^[0-9]+$ ]] && kill -0 "$fp" 2>/dev/null || rm -f "$f"; done
raw=$dir/claude-code.raw.json
[[ -e $raw ]] || printf '%s' "$in" > "$raw"
state=$(printf '%s' "$in" | jq -c --arg now "$(date +%s)" --argjson pid "$pid" --argjson compact "${AGENT_COMPACT_AT:-95}" '
  .context_window as $c | {
    provider: "claude-code",
    model: ((.model.display_name // .model.id // "?") | ascii_downcase),
    ctx_used_pct: ($c.used_percentage | if . == null then null else round end),
    ctx_left_tokens: (if $c.remaining_percentage != null and $c.context_window_size != null
                      then ($c.context_window_size * $c.remaining_percentage / 100 | floor) else null end),
    ctx_size: $c.context_window_size,
    ctx_to_compact_pct: ($c.used_percentage | if . == null then null else ([$compact - round, 0] | max) end),
    session: ((.session_id // "") | .[0:4]),
    cwd: (.workspace.current_dir // .cwd // ""),
    pid: $pid,
    ts: ($now | tonumber)
  }' 2>/dev/null) || state=
if [[ -n $state && -n $sid ]]; then
  tmp=$(mktemp "$dir/.claude-code.XXXXXX")
  printf '%s\n' "$state" > "$tmp"; mv "$tmp" "$dir/claude-code.$sid.json"
fi

# ---- segments: SEGMENTS is an ordered list of tokens; empty output is skipped, joined with SEP.
# list: STATUSLINE_SEGMENTS in agent.env (legacy: SEGMENTS in statusline.env). native: model cwd git ctx(=gauge, ◰ N%) cost | inner (INNER_COMMAND) | ext (every executable in segments.d/, sorted)
# a leading ~ runs the segment but hides its output (e.g. ~ext keeps a side-effect script running).
j() { printf '%s' "$in" | jq -r "$1" 2>/dev/null || true; }
cur=$(j '.workspace.current_dir // .cwd // empty')
run_cmd() { printf '%s' "$in" | timeout -k 1 3 sh -c "$1" 2>/dev/null || true; }   # INNER_COMMAND: a shell command line
run_exec() { printf '%s' "$in" | timeout -k 1 3 "$1" 2>/dev/null || true; }       # segments.d file: run directly, no shell parsing
seg() {
  case $1 in
    model) j '.model.display_name // empty' ;;
    cwd) if [[ -n $cur ]]; then t=$cur; [[ $t == "$HOME" || $t == "$HOME"/* ]] && t="~${t#"$HOME"}"; printf '%s' "$t"; fi ;;
    git) [[ -n $cur ]] && { b=$(timeout 1 git -C "$cur" branch --show-current 2>/dev/null || true)
           [[ -n $b ]] && { [[ -n $(timeout 1 git -C "$cur" --no-optional-locks status --porcelain -uno 2>/dev/null | head -1) ]] && b+='*'; printf '\xee\x82\xa0 %s' "$b"; }; } ;;
    cost) c=$(j '.cost.total_cost_usd // empty'); [[ -n $c ]] && LC_ALL=C printf '$%.2f' "$c" ;;
    ctx|gauge) p=$(j '.context_window.used_percentage // empty | round'); [[ -n $p ]] && printf '◰ %s%%' "$p" ;;
    inner) [[ -n ${INNER_COMMAND:-} ]] && run_cmd "$INNER_COMMAND" ;;
    ext) for x in "$cfgdir"/segments.d/*; do [[ -f $x && -x $x ]] && { (( SECONDS - t0 < 4 )) || break; run_exec "$x"; }; done ;;
  esac
}
t0=$SECONDS; parts=()
for tok in ${STATUSLINE_SEGMENTS:-${SEGMENTS:-model cwd git ctx}}; do
  hide=0; [[ $tok == '~'* ]] && { hide=1; tok=${tok#\~}; }
  o=$(seg "$tok" 2>/dev/null || true); o=${o//$'\n'/ }
  (( hide )) || [[ -z $o ]] || parts+=("$o")
done
out=; for x in "${parts[@]}"; do out+="${out:+${SEP- · }}$x"; done
printf '%s\n' "$out"
