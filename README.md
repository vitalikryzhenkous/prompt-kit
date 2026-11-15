# prompt-kit
Starship prompt with an AI-agent context gauge (`◰ 42% ◆ opus`), fed by CLI adapters (Claude Code today).

```
 dir  branch [status] ────── v22 ◰ 42% ◆ opus   14:05   user
❯
```

## Requirements
- Linux or WSL2 on x86_64 (the pinned starship binary is `x86_64-unknown-linux-musl`); bash (zsh: see Supported).
- Tools: `jq curl tar git python3` and coreutils (`sha256sum`, `timeout`). `bin/doctor.sh` checks them and prints an install hint.
- A Nerd Font in your terminal. On WSL the installer can add JetBrainsMono via winget (`--no-font` skips it); elsewhere install it yourself (nerdfonts.com).
- For the gauge: Claude Code, started at least once (`~/.claude` must exist; the adapter relies on `context_window.used_percentage` in its statusLine JSON,
  compare with `~/.cache/agent-status/claude-code.raw.json` after the first run).

## Install (Linux / WSL, bash)
```
# where the clone lives: PROMPT_KIT_DIR, default $XDG_DATA_HOME/prompt-kit (~/.local/share/prompt-kit)
PROMPT_KIT_DIR=${PROMPT_KIT_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/prompt-kit}
git clone https://github.com/vitalikryzhenkous/prompt-kit "$PROMPT_KIT_DIR" && cd "$PROMPT_KIT_DIR"
bin/install.sh --dry-run --with claude-code   # list every file it would touch
bin/install.sh --with claude-code
exec bash                                     # reload the shell, then:
bin/doctor.sh                                 # run from the clone directory
```
Preview without installing: `bin/preview.sh` (writes only to `/tmp`).

## What install changes
`bin/install.sh --dry-run [--with claude-code]` prints every step as `WOULD ...` and the list of files it would touch, and writes nothing.
Real run, in order. Each config file that already exists is first copied to `<file>.bak.<timestamp>` (once per run); the binary and the symlinks are not backed up:

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
(an old `statusLine` that install saved is put back), restores the pre-install `starship.toml` if there was one. It keeps the starship binary,
`~/.config/prompt-kit/`, the font and all `*.bak.*` files.

## Check and report
`bin/doctor.sh` prints PASS/FAIL/SKIP with a fix hint per line (tools, starship, hook, icons, adapter). Adapter checks are skipped
if `~/.claude` does not exist, and FAIL until a Claude Code session with the adapter has run; a shell that is not installed (zsh) is SKIP, i.e. not verified.
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

## How it works
Claude Code runs `adapters/claude-code/statusline.sh` on every refresh; it writes `~/.cache/agent-status/claude-code.<session>.json`.
Starship's `custom.agent*` modules call `prompt-kit-agent-read`, which picks the live sessions for the current directory and prints `◰ N% ◆ model`
(`◆ 2× ◰ N%` for several sessions, worst percentage).

## Configure
- Icon of a module: `bin/theme.sh icon git_branch nf-dev-git_branch` (modules: `directory git_branch nodejs time username`; a glyph, `nf-<set>-<name>` or `U+XXXX`).
- Gauge (what to show, TTL, scope, warn/root thresholds): `~/.config/prompt-kit/agent.env`. Status line segments: `STATUSLINE_SEGMENTS` in the same file.
  Details in `docs/wiki/Agents.md`.
- Pill colours: `pill` and `user_bg` in `[palettes.custom]` of `starship/starship.toml`.

## Troubleshooting
- Boxes instead of icons: the terminal font is not a Nerd Font.
- No gauge: with `AGENT_SCOPE=cwd` the shell must be inside (or above) the session's directory; or the session is older than `AGENT_TTL`.
- Field names changed in a new Claude Code version: compare `~/.cache/agent-status/claude-code.raw.json` with the adapter.
- Anything else: `bin/doctor.sh --report`, paste the output into an issue.

See `docs/wiki/Agents.md`. MIT.
