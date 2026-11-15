#!/usr/bin/env bash
# Render the prompt in a throwaway repo with a fake 42% agent state. Writes only to /tmp.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck disable=SC1091
. "$here/bin/versions.env"
cfg=${1:-$here/starship/starship.toml}
bindir=/tmp/starship-bin
if [[ -x $bindir/starship ]]; then :; elif command -v starship >/dev/null; then bindir=$(dirname "$(command -v starship)")
else
  mkdir -p /tmp/starship-dl "$bindir"
  url=https://github.com/starship/starship/releases/download/$STARSHIP_VERSION/starship-x86_64-unknown-linux-musl.tar.gz
  curl -fsSL "$url" -o /tmp/starship-dl/s.tgz
  echo "$STARSHIP_SHA256_linux_x86_64_musl  /tmp/starship-dl/s.tgz" | sha256sum -c - >&2
  tar -xzf /tmp/starship-dl/s.tgz -C "$bindir" starship
fi
repo=/tmp/preview-repo; rm -rf "$repo"; mkdir -p "$repo"; cd "$repo"
git init -q -b complete; echo '{}' > package.json
state=/tmp/preview-agent; rm -rf "$state"; mkdir -p "$state"
now=$(date +%s)
# two fake live sessions (pid = this shell and its parent, both alive): one here at 42%, one elsewhere at 75%
mk() { printf '{"provider":"claude-code","model":"%s","ctx_used_pct":%s,"ctx_left_tokens":116000,"ctx_size":200000,"session":"%s","cwd":"%s","pid":%s,"ts":%s}\n' "$1" "$2" "$3" "$4" "$5" "$now" > "$state/claude-code.$3.json"; }
mk opus "${PREVIEW_PCT:-42}" aaaa-1111 "$repo" $$
[[ ${PREVIEW_ONE:-0} == 1 ]] || mk sonnet 75 bbbb-2222 /tmp/preview-other $PPID
mkdir -p /tmp/preview-path; ln -sf "$here/bin/agent-read.sh" /tmp/preview-path/prompt-kit-agent-read
export PATH=/tmp/preview-path:$bindir:$PATH AGENT_STATUS_DIR=$state STARSHIP_CONFIG=$cfg
echo "== starship $("$bindir/starship" --version | head -1)"
echo "== ANSI"; starship prompt --terminal-width 90
echo; echo "== plain"; starship prompt --terminal-width 90 | sed 's/\x1b\[[0-9;]*m//g; s/\x01//g; s/\x02//g'
if [[ ${PREVIEW_SCOPES:-1} == 1 ]]; then
  strip() { sed 's/\x1b\[[0-9;]*m//g; s/\x01//g; s/\x02//g'; }
  echo; echo "== scope=cwd, in $repo (expect 1 session: 42%)";      starship prompt --terminal-width 90 | strip | head -1
  echo "== scope=any, in $repo (expect 2×, worst 75% -> warn)";   AGENT_SCOPE=any starship prompt --terminal-width 90 | strip | head -1
  mkdir -p /tmp/preview-unrelated; cd /tmp/preview-unrelated
  echo "== scope=cwd, in unrelated dir (expect no gauge)";        starship prompt --terminal-width 90 | strip | head -1
  echo "== scope=any, in unrelated dir (expect 2×)";              AGENT_SCOPE=any starship prompt --terminal-width 90 | strip | head -1
fi
