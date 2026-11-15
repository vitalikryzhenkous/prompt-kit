#!/bin/sh
# hook-block.sh bash|zsh — prints the rc block install.sh appends (kept here so it can be syntax-checked).
case ${1:-} in bash|zsh) ;; *) echo "usage: hook-block.sh bash|zsh" >&2; exit 2;; esac
cat <<HOOK

# prompt-kit
case ":\$PATH:" in *":\$HOME/.local/bin:"*) ;; *) export PATH="\$HOME/.local/bin:\$PATH";; esac
eval "\$(starship init $1)"
HOOK
