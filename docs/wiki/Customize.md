# Customize

## Node icon

1. Set the icon of this machine: `bin/theme.sh host-icon <glyph | nf-<set>-<name> | U+XXXX>` (e.g. `nf-md-server`); it is written to `~/.config/prompt-kit/host.env`, a local file outside git.
2. `bin/install.sh` creates that file with a commented example and wires the shell hook to read it (an existing file is never overwritten); open a new shell.
3. No value set: the default icon from `starship/starship.toml` is shown; an exported `PROMPT_KIT_HOST_ICON` wins over the file.
