# Sourced helper: pk_load_env FILE KEY...  — loads KEY=VALUE lines for the listed keys only.
# The file is parsed, never executed. A variable already set in the environment wins over the file.
pk_load_env() {
  local f=$1 k v; shift
  [[ -r $f ]] || return 0
  while IFS='=' read -r k v; do
    k=${k//[[:space:]]/}; [[ $k == \#* || -z $k ]] && continue
    [[ " $* " == *" $k "* ]] || continue
    [[ -n ${!k+x} ]] && continue
    v=${v#"${v%%[![:space:]]*}"}; v=${v%"${v##*[![:space:]]}"}
    [[ $v == \"*\" || $v == \'*\' ]] && v=${v:1:${#v}-2}
    printf -v "$k" '%s' "$v"
  done < "$f"
}
