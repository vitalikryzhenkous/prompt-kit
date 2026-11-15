#!/usr/bin/env bash
# usage: agent-read.sh normal|warn|root
# Reads per-session files <provider>.<session>.json, keeps the live ones for this directory,
# prints the gauge only if the worst session matches the level; else nothing.
# params: ~/.config/prompt-kit/agent.env (KEY=VALUE), an env var of the same name overrides.
# AGENT_SHOW=pct|tokens|bar|compact  AGENT_WARN_AT=70  AGENT_ROOT_AT=90  AGENT_TTL=300  AGENT_SCOPE=cwd|any  AGENT_COMPACT_AT=95
set -euo pipefail
level=${1:-normal}
# shellcheck disable=SC1091
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/env-load.sh"
pk_load_env "${PROMPT_KIT_CONFIG:-$HOME/.config/prompt-kit}/agent.env" AGENT_SHOW AGENT_TTL AGENT_SCOPE AGENT_WARN_AT AGENT_ROOT_AT AGENT_COMPACT_AT
dir=${AGENT_STATUS_DIR:-$HOME/.cache/agent-status}
show=${AGENT_SHOW:-pct}; ttl=${AGENT_TTL:-300}; warn=${AGENT_WARN_AT:-70}; root=${AGENT_ROOT_AT:-90}; scope=${AGENT_SCOPE:-cwd}; compact=${AGENT_COMPACT_AT:-95}
for v in ttl warn root compact; do [[ ${!v} =~ ^[0-9]+$ ]] || case $v in ttl) ttl=300;; warn) warn=70;; root) root=90;; compact) compact=95;; esac; done
here=$(realpath -m "${PWD:-.}")
shopt -s nullglob
files=()
for f in "$dir"/*.*.json; do   # old <provider>.json has no <session> part: ignored; so is *.raw.json
  [[ $f == *.raw.json ]] || files+=("$f")
done
(( ${#files[@]} )) || exit 0
now=$(date +%s); n=0; worst=-1; wleft=; wmodel=
while IFS=$'\t' read -r ts pid cwd pct left model; do
  [[ $ts =~ ^[0-9]+$ && $pct =~ ^[0-9]+$ && $pid =~ ^[0-9]+$ ]] || continue
  (( now - ts <= ttl )) || continue
  kill -0 "$pid" 2>/dev/null || continue
  if [[ $scope == cwd ]]; then
    c=$(realpath -m "$cwd")
    [[ $c != / ]] || continue   # a session started in / would match every shell
    [[ $here == "$c" || $here == "$c"/* || $c == "$here"/* ]] || continue
  fi
  n=$((n+1))
  if (( pct > worst )); then worst=$pct; wleft=$left; wmodel=$model; fi
done < <(jq -r '[.ts,.pid,.cwd,.ctx_used_pct,.ctx_left_tokens,.model]|map(.//"")|map(tostring)|@tsv' "${files[@]}" 2>/dev/null || true)
(( n )) || exit 0
pct=$worst
if (( pct >= root )); then actual=root; elif (( pct >= warn )); then actual=warn; else actual=normal; fi
[[ $actual == "$level" ]] || exit 0
case $show in
  tokens) [[ $wleft =~ ^[0-9]+$ ]] && txt="$((wleft/1000))k left" || txt="${pct}%" ;;
  compact) c=$((compact-pct)); (( c < 0 )) && c=0; txt="${c}% to compact" ;;
  bar) b=$(( (pct*5+50)/100 )); txt=$(printf '%*s' "$b" '' | tr ' ' '█')$(printf '%*s' "$((5-b))" '' | tr ' ' '░') ;;
  *) txt="${pct}%" ;;
esac
if (( n > 1 )); then printf '◆ %s× ◰ %s' "$n" "$txt"
else model=$(printf '%s' "$wmodel" | tr -cd '[:alnum:] ._-'); printf '◰ %s%s' "$txt" "${model:+ ◆ $model}"; fi
