# prompt-kit
Starship prompt with an AI-agent context gauge (`◰ 42% ◆ opus`), fed by CLI adapters (Claude Code today).

```
 dir  branch [status] ────── v22 ◰ 42% ◆ opus   14:05   user
❯
```

## Install (Linux / WSL, bash)
```
# where the clone lives: PROMPT_KIT_DIR, default $XDG_DATA_HOME/prompt-kit (~/.local/share/prompt-kit)
PROMPT_KIT_DIR=${PROMPT_KIT_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/prompt-kit}
git clone <your-remote>/prompt-kit "$PROMPT_KIT_DIR" && cd "$PROMPT_KIT_DIR"
bin/install.sh --dry-run --with claude-code   # list every file it would touch
bin/install.sh --with claude-code
exec bash && bin/doctor.sh
```
Preview without installing: `bin/preview.sh` (writes only to `/tmp`).

## What install changes
`bin/install.sh --dry-run [--with claude-code]` prints every step as `WOULD ...` and the list of files it would touch, and writes nothing.
Real run, in order (each file that already exists is first copied to `<file>.bak.<timestamp>`, once per run):

| What | Where | Backup |
|---|---|---|
| starship binary (pinned version, sha256-checked) | `~/.local/bin/starship` | – |
| prompt config (symlink to the repo) | `~/.config/starship.toml` | yes |
| gauge reader (symlink) | `~/.local/bin/prompt-kit-agent-read` | – |
| shell hook (one `# prompt-kit` block at the end) | `~/.bashrc` | yes |
| state dir | `~/.cache/agent-status/` (0700) | – |
| Nerd Font + font in the Windows Terminal profile of this distro (WSL only; skip with `--no-font`) | Windows host | `settings.json` |
| with `--with claude-code`: `statusLine` + `SessionEnd` hook | `~/.claude/settings.json` | yes |
| with `--with claude-code`: default config, never overwritten | `~/.config/prompt-kit/agent.env`, `statusline.env` | – |

`bin/uninstall.sh [--dry-run]` undoes it: removes the symlinks and the rc block, takes only our entries out of `settings.json`
(the old `statusLine` is put back), restores the pre-install `starship.toml` if there was one. It keeps the starship binary,
`~/.config/prompt-kit/`, the font and all `*.bak.*` files.

## Check and report
`bin/doctor.sh` prints PASS/FAIL with a fix hint per line (tools, starship, hook, icons, adapter).
`bin/doctor.sh --report` prints the same plus an environment header with home path, user name, host name and Windows user
replaced by `~`, `<user>`, `<host>`, so it is safe to paste into an issue.

## Supported
| OS / shell | Status |
|---|---|
| WSL / Linux bash | yes |
| zsh (`install.sh --shell zsh`) | hook block syntax-checked with `zsh -n` where zsh is installed; not run on a real zsh yet |
| macOS, fish, Windows pwsh | not yet |

| Agent | Status |
|---|---|
| Claude Code | yes (`statusLine` adapter) |

See `docs/wiki/Agents.md`. MIT.
