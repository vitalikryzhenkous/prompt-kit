# Sourced helper: required external tools and how to install them on this system.
PK_TOOLS="jq git curl tar sha256sum python3 timeout"
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
pk_missing_tools() { local t; for t in $PK_TOOLS; do command -v "$t" >/dev/null 2>&1 || echo "$t"; done; }
