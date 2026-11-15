#!/usr/bin/env bash
# PASS/FAIL checks with a fix hint each. Read-only.
set -uo pipefail
REPO=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
# shellcheck disable=SC1091
. "$REPO/bin/versions.env"
# --report: the same checks plus an environment header, scrubbed of personal data (safe to paste into an issue)
if [[ ${1:-} == --report ]]; then
  os=$( . /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-unknown}" )
  { echo "prompt-kit $(git -C "$REPO" describe --tags --always 2>/dev/null || echo unknown)"
    echo "os: $os; kernel: $(uname -r | cut -d. -f1-2); wsl: $(grep -qi microsoft /proc/version 2>/dev/null && echo yes || echo no); shell: $(basename "${SHELL:-?}")"
    echo "tools: jq $(jq --version 2>/dev/null || echo -), git $(git --version 2>/dev/null | awk '{print $3}'), curl $(curl --version 2>/dev/null | awk 'NR==1{print $2}'), python3 $(python3 -V 2>&1 | awk '{print $2}'), starship $(starship --version 2>/dev/null | awk 'NR==1{print $2}')"
    echo; "$0"; } 2>&1 \
  | sed -e "s|$HOME|~|g" -e "s|/mnt/c/Users/[^/ ]*|/mnt/c/Users/<user>|g" \
        -e "s|$(id -un)|<user>|g" -e "s|$(hostname 2>/dev/null || echo __nohost__)|<host>|g"
  exit 0
fi
bad=0
chk() { local name=$1 fix=$2; shift 2; if "$@" >/dev/null 2>&1; then echo "PASS  $name"; else echo "FAIL  $name  → $fix"; bad=1; fi; }
export PATH="$HOME/.local/bin:$PATH"
# shellcheck disable=SC1091
. "$REPO/bin/deps.sh"
for t in $PK_TOOLS; do chk "tool: $t" "$(pk_install_hint "$t")" command -v "$t"; done
chk "starship on PATH" "bin/install.sh" command -v starship
chk "starship version = $STARSHIP_VERSION" "bin/install.sh" bash -c "[[ v\$(starship --version | head -1 | awk '{print \$2}') == $STARSHIP_VERSION ]]"
chk "config symlink -> repo" "bin/install.sh" bash -c "[[ \$(readlink ~/.config/starship.toml) == '$REPO/starship/starship.toml' ]]"
chk "config renders (STARSHIP_CONFIG parse)" "fix TOML" bash -c "starship prompt >/dev/null"
chk "hook exactly once" "remove duplicate '# prompt-kit' in ~/.bashrc" bash -c "[[ \$(grep -c '^# prompt-kit' ~/.bashrc) == 1 ]]"
chk "hook is last in .bashrc" "move block to end of ~/.bashrc" bash -c "tail -n 1 ~/.bashrc | grep -q 'starship init bash'"
if grep -nE 'oh-my-posh|p10k|powerlevel' ~/.bashrc >/dev/null 2>&1; then echo "FAIL  no p10k/oh-my-posh in .bashrc  → disable it"; bad=1; else echo "PASS  no p10k/oh-my-posh in .bashrc"; fi
chk "agent reader linked" "bin/install.sh" test -x ~/.local/bin/prompt-kit-agent-read
if grep -qi microsoft /proc/version 2>/dev/null && command -v powershell.exe >/dev/null 2>&1; then
  chk "Nerd Font on Windows host" "winget install DEVCOM.JetBrainsMonoNerdFont" bash -c "powershell.exe -NoProfile -c \"Get-ChildItem C:\\Windows\\Fonts,\\\$env:LOCALAPPDATA\\Microsoft\\Windows\\Fonts -ErrorAction SilentlyContinue | Where-Object Name -like 'JetBrainsMono*'\" | grep -q ."
fi
chk "icon glyph in every module format" "bin/theme.sh icon <module> nf-<name>" "$REPO/bin/check-icons.sh"
f=$(ls -t ~/.cache/agent-status/*.json 2>/dev/null | grep -v '\.raw\.json$' | head -1 || true)
if [[ -n $f ]]; then age=$(( $(date +%s) - $(jq -r '.ts' "$f") )); (( age <= 120 )) && echo "PASS  agent state fresh (${age}s)" || { echo "FAIL  agent state stale (${age}s)  → adapter not running / session idle"; bad=1; }
else echo "FAIL  no agent state file  → start Claude Code with adapter wired"; bad=1; fi
chk "Claude Code statusLine → adapter" "bin/install.sh --with claude-code" bash -c "jq -e --arg c '$REPO/adapters/claude-code/statusline.sh' '.statusLine.command==\$c' ~/.claude/settings.json"
t=$(starship timings 2>/dev/null | awk -F'[│|]' '/ms/ {gsub(/[^0-9.]/,"",$3); if ($3+0>100) print}' || true)
[[ -z $t ]] && echo "PASS  no module > 100 ms" || { echo "FAIL  slow modules: $t"; bad=1; }
echo "hint: starship bug-report"; exit $bad
