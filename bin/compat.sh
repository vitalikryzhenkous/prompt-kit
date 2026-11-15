# Sourced helpers: GNU/BSD portability (Linux, macOS). No side effects on load.
# pk_sha256_check  — reads "<hash>  <file>" lines on stdin, like `sha256sum -c -`
pk_sha256_check() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum -c -
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 -c -
  else echo "no sha256sum or shasum found" >&2; return 1; fi
}
# pk_timeout [-k N] SECS CMD...  — GNU timeout, or gtimeout (brew coreutils); without either runs CMD unbounded
pk_timeout() {
  if command -v timeout >/dev/null 2>&1; then timeout "$@"
  elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$@"
  else
    [[ ${1:-} == -k ]] && shift 2
    shift
    "$@"
  fi
}
# pk_ppid PID  — parent pid: /proc on Linux, `ps -o ppid=` on macOS/BSD (no /proc)
pk_ppid() {
  if [[ -r /proc/$1/stat ]]; then awk '{print $4}' "/proc/$1/stat"
  else local p; p=$(ps -o ppid= -p "$1" 2>/dev/null) || return 1; printf '%s\n' "${p//[[:space:]]/}"; fi
}
# pk_comm PID  — process name: /proc/PID/comm on Linux; on macOS the basename of argv[0] (`ps -o args=`), because
# `ps -o comm=` there is the executable path, which for a native Claude Code install is a version-named file, not "claude"
pk_comm() {
  if [[ -r /proc/$1/comm ]]; then cat "/proc/$1/comm"
  else local a; a=$(ps -o args= -p "$1" 2>/dev/null) || return 1; a=${a%% *}; printf '%s\n' "${a##*/}"; fi
}
# pk_realpath PATH  — absolute, normalized path; does not need to exist (like `realpath -m`)
pk_realpath() {
  local p=$1 d out=() seg
  if realpath -m / >/dev/null 2>&1; then realpath -m -- "$p"; return; fi
  [[ $p == /* ]] || p="$PWD/$p"
  if [[ -d $p ]]; then (cd -P -- "$p" 2>/dev/null && pwd -P) && return; fi
  local IFS=/
  for seg in $p; do
    case $seg in ''|.) ;; ..) (( ${#out[@]} )) && unset 'out[${#out[@]}-1]';; *) out+=("$seg");; esac
  done
  printf '/%s\n' "${out[*]}"
}
