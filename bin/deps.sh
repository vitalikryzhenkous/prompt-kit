# Sourced helper: required external tools and how to install them on this system.
PK_TOOLS="jq git curl tar python3"   # + sha256sum|shasum, and timeout|gtimeout (optional): see pk_missing_tools
pk_install_hint() {   # $1 = tool; prints a package-manager command (never runs it)
  local pkg=$1
  case $1 in sha256sum|timeout) pkg=coreutils;; esac
  if command -v apt-get >/dev/null 2>&1; then echo "sudo apt-get install $pkg"
  elif command -v dnf >/dev/null 2>&1; then echo "sudo dnf install $pkg"
  elif command -v pacman >/dev/null 2>&1; then echo "sudo pacman -S $pkg"
  elif command -v apk >/dev/null 2>&1; then echo "sudo apk add $pkg"
  elif command -v brew >/dev/null 2>&1; then
    case $1 in sha256sum|timeout) echo "brew install coreutils (then use gsha256sum/gtimeout, or put coreutils gnubin on PATH)";; *) echo "brew install $pkg";; esac
  else echo "install '$pkg' with your package manager"; fi
}
pk_missing_tools() {
  local t; for t in $PK_TOOLS; do command -v "$t" >/dev/null 2>&1 || echo "$t"; done
  command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1 || echo sha256sum
  command -v timeout >/dev/null 2>&1 || command -v gtimeout >/dev/null 2>&1 || echo timeout
}

# pk_put FILE  — writes stdin to FILE via a temp file in the same dir, then `cat > FILE` (keeps symlinks and permissions)
pk_put() { local f=$1 t; t=$(mktemp "$f.pk.XXXXXX") || return 1; cat > "$t" && cat "$t" > "$f"; local r=$?; rm -f "$t"; return $r; }

# pk_wt_settings — path of the Windows Terminal settings.json of the CURRENT Windows user (WSL only); empty if unsure.
pk_wt_settings() {
  local up d f
  up=$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r') && [[ -n $up ]] && d=$(wslpath -u "$up" 2>/dev/null) || d=
  if [[ -n $d ]]; then f=$(ls "$d"/AppData/Local/Packages/Microsoft.WindowsTerminal*/LocalState/settings.json 2>/dev/null | head -1)
  else   # fall back to the glob only when there is exactly one Windows user profile with Windows Terminal
    local all; all=$(ls /mnt/c/Users/*/AppData/Local/Packages/Microsoft.WindowsTerminal*/LocalState/settings.json 2>/dev/null)
    [[ $(printf '%s\n' "$all" | grep -c .) == 1 ]] && f=$all
  fi
  printf '%s' "${f:-}"
}
