#!/usr/bin/env bash
# prompt-kit installer (linux / WSL, bash). Idempotent. Flags: --dry-run --no-font --no-hook --with claude-code
set -euo pipefail
REPO=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
# shellcheck disable=SC1091
. "$REPO/bin/versions.env"
# PROMPT_KIT_DIR (default $XDG_DATA_HOME/prompt-kit) is where the README clones to; the repo is always found from this script's location
want=${PROMPT_KIT_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/prompt-kit}
[[ -d $want && $(cd "$want" && pwd -P) == "$(cd "$REPO" && pwd -P)" ]] || echo "• note: installing from $REPO (PROMPT_KIT_DIR default would be $want); symlinks and settings will point here" >&2
DRY=0; FONT=1; HOOK=1; WITH=()
while (( $# )); do case $1 in
  --dry-run) DRY=1;; --no-font) FONT=0;; --no-hook) HOOK=0;;
  --with) shift; WITH+=("$1");;
  *) echo "unknown flag: $1" >&2; exit 2;; esac; shift; done
TS=$(date +%Y%m%d-%H%M%S); FAILS=(); TOUCHED=()
say() { echo "• $*"; }
touch_() { TOUCHED+=("$1"); }
fail() { FAILS+=("$1"); echo "✗ $1" >&2; }
backup() { local f=$1; if [[ -e $f || -L $f ]]; then if (( DRY )); then say "WOULD backup $f -> $f.bak.$TS"; else cp -P "$f" "$f.bak.$TS"; fi; touch_ "$f.bak.$TS"; fi; }

for t in jq curl tar sha256sum; do command -v "$t" >/dev/null || { echo "missing: $t" >&2; exit 1; }; done
grep -qi microsoft /proc/version 2>/dev/null && WSL=1 || WSL=0
say "mode: $([[ $DRY == 1 ]] && echo DRY-RUN || echo APPLY); WSL=$WSL; shell=bash; with=${WITH[*]:-none}"

# 1. starship (pinned)
have=$(starship --version 2>/dev/null | head -1 | awk '{print $2}' || true)
if [[ "v$have" == "$STARSHIP_VERSION" ]]; then say "starship $have already installed"
else
  touch_ "$HOME/.local/bin/starship"
  if (( DRY )); then say "WOULD download starship $STARSHIP_VERSION (sha256-pinned) -> ~/.local/bin/starship"
  else
    tmp=$(mktemp -d); mkdir -p "$HOME/.local/bin"
    curl -fsSL "https://github.com/starship/starship/releases/download/$STARSHIP_VERSION/starship-x86_64-unknown-linux-musl.tar.gz" -o "$tmp/s.tgz" \
      && echo "$STARSHIP_SHA256_linux_x86_64_musl  $tmp/s.tgz" | sha256sum -c - >/dev/null \
      && tar -xzf "$tmp/s.tgz" -C "$HOME/.local/bin" starship && say "starship $STARSHIP_VERSION installed" \
      || fail "starship download/verify failed"
    rm -rf "$tmp"
  fi
fi

# 2. config symlink
cfg=$HOME/.config/starship.toml; want=$REPO/starship/starship.toml
if [[ -L $cfg && $(readlink "$cfg") == "$want" ]]; then say "config symlink ok"
else
  touch_ "$cfg"; backup "$cfg"
  if (( DRY )); then say "WOULD symlink $cfg -> $want"; else mkdir -p "$HOME/.config"; ln -sfn "$want" "$cfg"; say "linked $cfg"; fi
fi

# 3. agent reader + state dir
rd=$HOME/.local/bin/prompt-kit-agent-read
if [[ -L $rd && $(readlink "$rd") == "$REPO/bin/agent-read.sh" ]]; then say "agent-read symlink ok"
else touch_ "$rd"; if (( DRY )); then say "WOULD symlink $rd -> bin/agent-read.sh"; else mkdir -p "$HOME/.local/bin"; ln -sfn "$REPO/bin/agent-read.sh" "$rd"; fi; fi
touch_ "$HOME/.cache/agent-status/"
(( DRY )) && say "WOULD mkdir -m700 ~/.cache/agent-status" || { mkdir -p "$HOME/.cache/agent-status"; chmod 700 "$HOME/.cache/agent-status"; }

# 4. bashrc hook (once, last)
rc=$HOME/.bashrc
if (( HOOK )); then
  if grep -q '^# prompt-kit' "$rc" 2>/dev/null; then say "hook already in .bashrc"
  else
    grep -nE 'oh-my-posh|p10k|powerlevel|conda initialize|^ *(export )?PS1=' "$rc" 2>/dev/null | sed 's/^/  ⚠ possible prompt override: /' || true
    touch_ "$rc"; backup "$rc"
    if (( DRY )); then say "WOULD append '# prompt-kit' block (PATH + starship init bash) to $rc"
    else cat >> "$rc" <<'HOOK'

# prompt-kit
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH";; esac
eval "$(starship init bash)"
HOOK
      say "hook appended to $rc"; fi
  fi
fi

# 5. Nerd Font on the Windows host (WSL)
if (( FONT && WSL )); then
  if command -v powershell.exe >/dev/null; then
    if (( DRY )); then say "WOULD run: powershell.exe winget install --id DEVCOM.JetBrainsMonoNerdFont"
    else powershell.exe -NoProfile -c "winget install --id DEVCOM.JetBrainsMonoNerdFont --accept-package-agreements --accept-source-agreements" >/dev/null 2>&1 \
         && say "font installed/present" || echo "⚠ winget failed or font already installed; manual: https://www.nerdfonts.com/font-downloads (JetBrainsMono)"; fi
  else echo "⚠ powershell.exe not reachable: install JetBrainsMono Nerd Font manually"; fi
  wt=$(ls /mnt/c/Users/*/AppData/Local/Packages/Microsoft.WindowsTerminal*/LocalState/settings.json 2>/dev/null | head -1 || true)
  if [[ -n $wt ]] && jq -e . "$wt" >/dev/null 2>&1; then
    touch_ "$wt"; backup "$wt"
    expr='(.profiles.list[] | select(.source=="Windows.Terminal.Wsl" or ((.name//"")|test("Ubuntu"))) | .font.face) = "JetBrainsMono Nerd Font"'
    if (( DRY )); then say "WOULD set WSL profile font.face in Windows Terminal settings.json"
    else out=$(jq "$expr" "$wt") && cat <<<"$out" > "$wt" && say "Windows Terminal font set"; fi
  else echo "⚠ Windows Terminal settings.json not found / not plain JSON: set font 'JetBrainsMono Nerd Font' in UI"; fi
fi

# 6. Claude Code adapter (statusLine key only; old command wrapped)
for w in "${WITH[@]:-}"; do [[ $w == claude-code ]] || continue
  S=$HOME/.claude/settings.json; ours=$REPO/adapters/claude-code/statusline.sh
  cur=$(jq -r '.statusLine.command // empty' "$S")
  if [[ $cur == "$ours" ]]; then say "statusLine already points to adapter"
  else
    say "statusLine BEFORE: $(jq -c '.statusLine // null' "$S")"
    touch_ "$S"; backup "$S"
    if [[ -n $cur ]]; then touch_ "$HOME/.config/prompt-kit/inner-statusline"   # keep the foreign command; migrated into statusline.env below
      (( DRY )) && say "WOULD save old command to ~/.config/prompt-kit/inner-statusline" \
        || { mkdir -p "$HOME/.config/prompt-kit"; printf '%s\n' "$cur" > "$HOME/.config/prompt-kit/inner-statusline"; chmod 600 "$HOME/.config/prompt-kit/inner-statusline"; }; fi
    after=$(jq -c --arg c "$ours" '.statusLine.type="command" | .statusLine.command=$c | .statusLine' "$S")
    say "statusLine AFTER:  $after"
    if (( ! DRY )); then out=$(jq --arg c "$ours" '.statusLine.type="command" | .statusLine.command=$c' "$S") && cat <<<"$out" > "$S"; fi
  fi
  # config: agent.env (gauge parameters) and statusline.env (segments); never overwritten
  cfgd=$HOME/.config/prompt-kit; ae=$cfgd/agent.env; se=$cfgd/statusline.env; oldin=$cfgd/inner-statusline
  if [[ ! -e $ae ]]; then touch_ "$ae"
    (( DRY )) && say "WOULD create $ae (documented defaults)" || { mkdir -p "$cfgd"; cat > "$ae" <<'ENV'
# prompt-kit gauge parameters (KEY=VALUE; an env var of the same name wins). Read by the adapter and the reader.
# AGENT_SHOW: pct | tokens | bar | compact
AGENT_SHOW=pct
# seconds a session state stays valid (its pid must also be alive)
AGENT_TTL=300
# cwd = sessions in/around the current dir; any = all live sessions
AGENT_SCOPE=cwd
AGENT_WARN_AT=70
AGENT_ROOT_AT=90
# Claude Code's JSON has no compact threshold field: this is a configured value
AGENT_COMPACT_AT=95
# statusline segments, in order (opt-in: cost, ext, inner): model cwd git ctx cost | ext (executables in segments.d/) | inner. Native ctx = ◰ N%
STATUSLINE_SEGMENTS="model cwd git ctx"
ENV
      chmod 600 "$ae"; say "created $ae"; }; fi
  if [[ ! -e $se ]]; then touch_ "$se"
    if [[ -s $oldin ]]; then   # migration: the old wrapped command becomes INNER_COMMAND, output stays as it was
      (( DRY )) && say "WOULD create $se from $oldin (SEGMENTS=\"inner gauge\", SEP=\" \")" \
        || { mkdir -p "$cfgd"; printf '# migrated from inner-statusline (output unchanged); the old file is still used, do not delete it\nSEGMENTS="inner gauge"\nSEP=" "\nINNER_COMMAND='"'"'sh %s'"'"'\n' "$oldin" > "$se"; chmod 600 "$se"; say "migrated $oldin -> $se (old file kept)"; }
    else
      (( DRY )) && say "WOULD create $se (default segments)" \
        || { mkdir -p "$cfgd/segments.d"; printf '# separator; segment list is STATUSLINE_SEGMENTS in agent.env ; ~name = run but hide\nSEP=" · "\n' > "$se"; chmod 600 "$se"; say "created $se"; }
    fi; fi
  # SessionEnd hook removes this session's state file (idempotent: matched by command path)
  hk=$REPO/adapters/claude-code/session-end.sh
  if jq -e --arg c "$hk" '[.hooks.SessionEnd[]?.hooks[]?.command]|index($c)' "$S" >/dev/null 2>&1; then say "SessionEnd hook already set"
  else
    touch_ "$S"; backup "$S"
    if (( DRY )); then say "WOULD add SessionEnd hook $hk to settings.json"
    else out=$(jq --arg c "$hk" '.hooks.SessionEnd += [{"hooks":[{"type":"command","command":$c}]}]' "$S") && cat <<<"$out" > "$S"; say "SessionEnd hook added"; fi
  fi
  # legacy single-file state (pre per-session): reader ignores it, the installer removes it
  old=$HOME/.cache/agent-status/claude-code.json
  if [[ -e $old ]]; then touch_ "$old"; (( DRY )) && say "WOULD remove legacy $old" || { rm -f "$old"; say "removed legacy $old"; }; fi
done

echo; echo "== files touched (${#TOUCHED[@]})"; printf '  %s\n' "${TOUCHED[@]}"
if (( ${#FAILS[@]} )); then echo "== FAILED: ${#FAILS[@]}" >&2; exit 1; fi
(( DRY )) && echo "== dry-run only, nothing written" || echo "== done: run 'exec bash' then bin/doctor.sh"
