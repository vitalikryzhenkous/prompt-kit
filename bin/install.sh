#!/usr/bin/env bash
# prompt-kit installer (linux / WSL / macOS; bash or zsh hook). Idempotent. Flags: --dry-run --no-font --no-hook --shell bash|zsh --with claude-code
set -euo pipefail
REPO=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
# shellcheck disable=SC1091
. "$REPO/bin/versions.env"
# PROMPT_KIT_DIR (README clone target, default $XDG_DATA_HOME/prompt-kit) does not move anything: the repo is found from this
# script's location. If it is set and points elsewhere, say so, because the symlinks/settings will point at the real location.
if [[ -n ${PROMPT_KIT_DIR:-} && $(cd "$PROMPT_KIT_DIR" 2>/dev/null && pwd -P) != "$(cd "$REPO" && pwd -P)" ]]; then
  echo "• note: PROMPT_KIT_DIR=$PROMPT_KIT_DIR but installing from $REPO; symlinks and settings will point to $REPO" >&2
fi
DRY=0; FONT=1; HOOK=1; WITH=(); KIND=$(basename "${SHELL:-bash}"); [[ $KIND == zsh ]] || KIND=bash
while (( $# )); do case $1 in
  --dry-run) DRY=1;; --no-font) FONT=0;; --no-hook) HOOK=0;;
  --shell) shift; KIND=${1:-}; [[ $KIND == bash || $KIND == zsh ]] || { echo "--shell bash|zsh" >&2; exit 2; };;
  --with) shift; WITH+=("$1");;
  *) echo "unknown flag: $1" >&2; exit 2;; esac; shift; done
TS=$(date +%Y%m%d-%H%M%S); FAILS=(); TOUCHED=()
say() { echo "• $*"; }
touch_() { TOUCHED+=("$1"); }
fail() { FAILS+=("$1"); echo "✗ $1" >&2; }
BACKED=$'\n'   # one backup per file per run: a second one would overwrite the pre-install original (newline list: macOS bash 3.2 has no declare -A)
backup() { local f=$1; [[ $BACKED == *$'\n'"$f"$'\n'* ]] && return 0; BACKED+="$f"$'\n'; if [[ -e $f || -L $f ]]; then if (( DRY )); then say "WOULD backup $f -> $f.bak.$TS"; else cp -P "$f" "$f.bak.$TS"; fi; touch_ "$f.bak.$TS"; fi; }

# shellcheck disable=SC1091
. "$REPO/bin/deps.sh"
# shellcheck disable=SC1091
. "$REPO/bin/compat.sh"
hard=0
for t in $(pk_missing_tools); do
  case $t in jq|curl|tar|sha256sum) echo "missing (required): $t  → $(pk_install_hint "$t")" >&2; hard=1;;
             *) echo "⚠ missing (some features): $t  → $(pk_install_hint "$t")" >&2;; esac
done
(( hard == 0 )) || exit 1
grep -qi microsoft /proc/version 2>/dev/null && WSL=1 || WSL=0
[[ $(uname -s) == Darwin ]] && MAC=1 || MAC=0
say "mode: $([[ $DRY == 1 ]] && echo DRY-RUN || echo APPLY); WSL=$WSL; macOS=$MAC; shell=$KIND; with=${WITH[*]:-none}"
# brew_get ARGS...  — macOS: `brew install ARGS` (no sudo); a failure is recorded, never aborts the run
brew_get() {
  if ! command -v brew >/dev/null 2>&1; then fail "Homebrew not found  → https://brew.sh, then: brew install $*"
  elif (( DRY )); then say "WOULD run: brew install $*"
  else brew install "$@" && say "brew install $* done" || fail "brew install $* failed"; fi
}

# 1. starship (pinned on Linux x86_64; Homebrew's current formula on macOS)
have=$(starship --version 2>/dev/null | head -1 | awk '{print $2}' || true)
if [[ "v$have" == "$STARSHIP_VERSION" ]]; then say "starship $have already installed"
elif [[ -n $have && $(uname -s)-$(uname -m) != Linux-x86_64 ]]; then   # the pinned binary is linux x86_64 only
  say "starship $have already installed (pinned $STARSHIP_VERSION is Linux x86_64 only; using yours)"
elif (( MAC )); then touch_ "brew: starship"; brew_get starship
elif [[ $(uname -s)-$(uname -m) != Linux-x86_64 ]]; then
  fail "no starship and no pinned binary for $(uname -s)-$(uname -m)  → $(pk_install_hint starship)"
else
  touch_ "$HOME/.local/bin/starship"
  if (( DRY )); then say "WOULD download starship $STARSHIP_VERSION (sha256-pinned) -> ~/.local/bin/starship"
  else
    tmp=$(mktemp -d); mkdir -p "$HOME/.local/bin"
    curl -fsSL "https://github.com/starship/starship/releases/download/$STARSHIP_VERSION/starship-x86_64-unknown-linux-musl.tar.gz" -o "$tmp/s.tgz" \
      && echo "$STARSHIP_SHA256_linux_x86_64_musl  $tmp/s.tgz" | pk_sha256_check >/dev/null \
      && tar -xzf "$tmp/s.tgz" -C "$HOME/.local/bin" starship && say "starship $STARSHIP_VERSION installed" \
      || fail "starship download/verify failed"
    rm -rf "$tmp"
  fi
fi
# macOS has no timeout(1): coreutils gives gtimeout, which bounds the statusline segments (bin/compat.sh pk_timeout)
if (( MAC )) && ! command -v timeout >/dev/null 2>&1 && ! command -v gtimeout >/dev/null 2>&1; then touch_ "brew: coreutils"; brew_get coreutils; fi

# 2. config symlink
cfg=$HOME/.config/starship.toml; want=$REPO/starship/starship.toml
if [[ -L $cfg && $(readlink "$cfg") == "$want" ]]; then say "config symlink ok"
else
  touch_ "$cfg"; backup "$cfg"
  if (( DRY )); then say "WOULD symlink $cfg -> $want"
  else
    # manifest: which backup holds the pre-install file (written once; uninstall restores strictly from it)
    mf=$HOME/.config/prompt-kit/install-manifest; mkdir -p "$HOME/.config/prompt-kit"
    if ! grep -q '^starship.toml=' "$mf" 2>/dev/null; then
      if [[ -e $cfg || -L $cfg ]]; then echo "starship.toml=$cfg.bak.$TS" >> "$mf"; else echo "starship.toml=NONE" >> "$mf"; fi
    fi
    mkdir -p "$HOME/.config"; ln -sfn "$want" "$cfg"; say "linked $cfg"
  fi
fi

# 3. agent reader + state dir
rd=$HOME/.local/bin/prompt-kit-agent-read
if [[ -L $rd && $(readlink "$rd") == "$REPO/bin/agent-read.sh" ]]; then say "agent-read symlink ok"
else touch_ "$rd"; if (( DRY )); then say "WOULD symlink $rd -> bin/agent-read.sh"; else mkdir -p "$HOME/.local/bin"; ln -sfn "$REPO/bin/agent-read.sh" "$rd"; fi; fi
touch_ "$HOME/.cache/agent-status/"
(( DRY )) && say "WOULD mkdir -m700 ~/.cache/agent-status" || { mkdir -p "$HOME/.cache/agent-status"; chmod 700 "$HOME/.cache/agent-status"; }

# 4. shell hook (once, last): ~/.bashrc or ~/.zshrc, block text from bin/hook-block.sh
rc=$HOME/.${KIND}rc
if (( HOOK )); then
  if grep -q '^# prompt-kit' "$rc" 2>/dev/null; then say "hook already in $rc"
  else
    grep -nE 'oh-my-posh|p10k|powerlevel|conda initialize|^ *(export )?PS1=' "$rc" 2>/dev/null | sed 's/^/  ⚠ possible prompt override: /' || true
    touch_ "$rc"; backup "$rc"
    if (( DRY )); then say "WOULD append '# prompt-kit' block (PATH + starship init $KIND) to $rc"
    else "$REPO/bin/hook-block.sh" "$KIND" >> "$rc"; say "hook appended to $rc"; fi
  fi
fi

# 5. Nerd Font on the Windows host (WSL)
if (( FONT && WSL )); then
  if command -v powershell.exe >/dev/null; then
    if (( DRY )); then say "WOULD run: powershell.exe winget install --id DEVCOM.JetBrainsMonoNerdFont"
    else powershell.exe -NoProfile -c "winget install --id DEVCOM.JetBrainsMonoNerdFont --accept-package-agreements --accept-source-agreements" >/dev/null 2>&1 \
         && say "font installed/present" || echo "⚠ winget failed or font already installed; manual: https://www.nerdfonts.com/font-downloads (JetBrainsMono)"; fi
  else echo "⚠ powershell.exe not reachable: install JetBrainsMono Nerd Font manually"; fi
  wt=$(pk_wt_settings)
  distro=${WSL_DISTRO_NAME:-}
  # profile = the Windows Terminal WSL profile whose name is this distro's name (exact match, not "Ubuntu" guesses)
  sel='.profiles.list[]? | select(.source=="Windows.Terminal.Wsl" and .name==$d)'
  if [[ -n $wt ]] && jq -e . "$wt" >/dev/null 2>&1; then
    if [[ -z $distro ]]; then echo "⚠ WSL_DISTRO_NAME is empty: set the font in the Windows Terminal UI"
    elif [[ $(jq --arg d "$distro" "[$sel]|length" "$wt") != 1 ]]; then echo "⚠ no single Windows Terminal profile named '$distro': set font 'JetBrainsMono Nerd Font' in its UI"
    else
      touch_ "$wt"; backup "$wt"
      expr="($sel | .font.face) = \"JetBrainsMono Nerd Font\""
      if (( DRY )); then say "WOULD set font.face of the '$distro' profile in Windows Terminal settings.json"
      else out=$(jq --arg d "$distro" "$expr" "$wt") && pk_put "$wt" <<<"$out" && say "Windows Terminal font set for '$distro'"; fi
    fi
  else echo "⚠ Windows Terminal settings.json not found / not plain JSON: set font 'JetBrainsMono Nerd Font' in UI"; fi
fi
# 5b. Nerd Font on macOS (Homebrew cask -> ~/Library/Fonts); the terminal's font setting stays manual
if (( FONT && MAC )); then
  if compgen -G "$HOME/Library/Fonts/JetBrainsMonoNerdFont*" >/dev/null || compgen -G "/Library/Fonts/JetBrainsMonoNerdFont*" >/dev/null; then
    say "JetBrainsMono Nerd Font already installed"
  else touch_ "brew: --cask font-jetbrains-mono-nerd-font"; brew_get --cask font-jetbrains-mono-nerd-font; fi
  say "set font 'JetBrainsMono Nerd Font' in your terminal's settings (Terminal.app / iTerm2 / Ghostty / VS Code)"
fi

# 6. Claude Code adapter (statusLine key only; old command wrapped)
for w in "${WITH[@]:-}"; do [[ $w == claude-code ]] || continue
  S=$HOME/.claude/settings.json; ours=$REPO/adapters/claude-code/statusline.sh
  if [[ ! -f $S ]]; then   # Claude Code never started on this machine: start from an empty settings file
    if (( DRY )); then say "WOULD create $S ({}) — then wire statusLine and the SessionEnd hook"; continue
    else mkdir -p "$HOME/.claude"; echo '{}' > "$S"; say "created $S"; fi
  fi
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
    if (( ! DRY )); then out=$(jq --arg c "$ours" '.statusLine.type="command" | .statusLine.command=$c' "$S") && pk_put "$S" <<<"$out"; fi
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
    else out=$(jq --arg c "$hk" '.hooks.SessionEnd += [{"hooks":[{"type":"command","command":$c}]}]' "$S") && pk_put "$S" <<<"$out"; say "SessionEnd hook added"; fi
  fi
  # legacy single-file state (pre per-session): reader ignores it, the installer removes it
  old=$HOME/.cache/agent-status/claude-code.json
  if [[ -e $old ]]; then touch_ "$old"; (( DRY )) && say "WOULD remove legacy $old" || { rm -f "$old"; say "removed legacy $old"; }; fi
done

echo; echo "== files touched (${#TOUCHED[@]})"; printf '  %s\n' "${TOUCHED[@]}"
if (( ${#FAILS[@]} )); then echo "== FAILED: ${#FAILS[@]}" >&2; exit 1; fi
(( DRY )) && echo "== dry-run only, nothing written" || echo "== done: run 'exec $KIND' then bin/doctor.sh"
