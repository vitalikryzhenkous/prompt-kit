#!/usr/bin/env bash
# usage: agent-read.sh normal|warn|root
# Prints the gauge only if the freshest state file matches the level; else prints nothing.
set -euo pipefail
level=${1:-normal}
dir=${AGENT_STATUS_DIR:-$HOME/.cache/agent-status}
show=${AGENT_SHOW:-pct}; ttl=${AGENT_TTL:-120}; warn=${AGENT_WARN_AT:-70}; root=${AGENT_ROOT_AT:-90}
f=$(ls -t "$dir"/*.json 2>/dev/null | grep -v '\.raw\.json$' | head -1 || true)
[[ -n $f ]] || exit 0
IFS=$'\t' read -r ts pct left model < <(jq -r '[.ts,.ctx_used_pct,.ctx_left_tokens,.model]|map(.//"")|@tsv' "$f") || exit 0
[[ $ts =~ ^[0-9]+$ && $pct =~ ^[0-9]+$ ]] || exit 0
(( $(date +%s) - ts <= ttl )) || exit 0
if (( pct >= root )); then actual=root; elif (( pct >= warn )); then actual=warn; else actual=normal; fi
[[ $actual == "$level" ]] || exit 0
model=$(printf '%s' "$model" | tr -cd '[:alnum:] ._-')
case $show in
  tokens) [[ $left =~ ^[0-9]+$ ]] && txt="$((left/1000))k left" || txt="${pct}%" ;;
  bar) n=$(( (pct*5+50)/100 )); txt=$(printf '%*s' "$n" '' | tr ' ' '█')$(printf '%*s' "$((5-n))" '' | tr ' ' '░') ;;
  *) txt="${pct}%" ;;
esac
printf '◰ %s%s' "$txt" "${model:+ ◆ $model}"
