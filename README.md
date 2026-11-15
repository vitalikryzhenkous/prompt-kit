# prompt-kit
Starship prompt with an AI-agent context gauge (`◰ 42% ◆ opus`), fed by CLI adapters (Claude Code today).

```
 dir  branch [status] ────── v22 ◰ 42% ◆ opus   14:05   user
❯
```

## Install (Linux / WSL, bash)
```
git clone <your-remote>/prompt-kit ~/apps/prompt-kit && cd ~/apps/prompt-kit
bin/install.sh --dry-run --with claude-code   # list every file it would touch
bin/install.sh --with claude-code
exec bash && bin/doctor.sh
```
Preview without installing: `bin/preview.sh` (writes only to `/tmp`).

## Supported
| OS / shell | Status |
|---|---|
| WSL / Linux bash | yes |
| macOS zsh, fish, Windows pwsh | not yet |

| Agent | Status |
|---|---|
| Claude Code | yes (`statusLine` adapter) |

See `docs/wiki/Agents.md`. Backups are `*.bak.<timestamp>` next to each changed file. MIT.
