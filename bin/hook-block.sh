#!/bin/sh
# hook-block.sh bash|zsh — prints the rc block install.sh appends (kept here so it can be syntax-checked).
case ${1:-} in bash|zsh) ;; *) echo "usage: hook-block.sh bash|zsh" >&2; exit 2;; esac
cat <<HOOK

# prompt-kit
case ":\$PATH:" in *":\$HOME/.local/bin:"*) ;; *) export PATH="\$HOME/.local/bin:\$PATH";; esac
# node icon: parsed (never executed) from a local file outside git; an exported variable wins
_pk_i=\$(sed -n 's/^PROMPT_KIT_HOST_ICON=//p' "\$HOME/.config/prompt-kit/host.env" 2>/dev/null | tail -n 1); [ -n "\$_pk_i" ] && export PROMPT_KIT_HOST_ICON="\${PROMPT_KIT_HOST_ICON:-\$_pk_i}"; unset _pk_i
eval "\$(starship init $1)"
HOOK
