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
printf '{"provider":"claude-code","model":"opus","ctx_used_pct":%s,"ctx_left_tokens":116000,"ctx_size":200000,"session":"a1b2","cwd_base":"demo","ts":%s}\n' "${PREVIEW_PCT:-42}" "$(date +%s)" > "$state/claude-code.json"
mkdir -p /tmp/preview-path; ln -sf "$here/bin/agent-read.sh" /tmp/preview-path/prompt-kit-agent-read
export PATH=/tmp/preview-path:$bindir:$PATH AGENT_STATUS_DIR=$state STARSHIP_CONFIG=$cfg
echo "== starship $("$bindir/starship" --version | head -1)"
echo "== ANSI"; starship prompt --terminal-width 90
echo; echo "== plain"; starship prompt --terminal-width 90 | sed 's/\x1b\[[0-9;]*m//g; s/\x01//g; s/\x02//g'
