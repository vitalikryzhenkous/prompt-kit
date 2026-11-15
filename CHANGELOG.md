# Changelog

## Unreleased
- Initial: starship config, agent gauge, Claude Code adapter, preview/install/doctor.
- SessionEnd runs executables from `~/.config/prompt-kit/session-end.d/` (no vendor-specific hook in the repo).
- macOS-friendly helpers in `bin/compat.sh`: `shasum -a 256`, `gtimeout`/no timeout, bash `realpath -m`; starship binary download stays Linux x86_64 only.

## Roadmap (not implemented)
- `bin/theme.sh`: `color|palette|layout|move|agent` subcommands, palettes (nord, dracula, mono), layouts (split, left, minimal, oneline, rightprompt). Today only `theme.sh icon` exists.
- compact threshold: Claude Code's JSON has no such field; `AGENT_COMPACT_AT` stays a configured value (default 95).
- install.ps1 / doctor.ps1 (Windows native), fish, other agent adapters (Codex, Gemini, OpenCode, Cursor: not checked).
- macOS: real run not yet verified; starship binary must come from `brew install starship`.
