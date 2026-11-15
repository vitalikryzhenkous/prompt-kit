# Agents
## State contract
`~/.cache/agent-status/<provider>.json`, mode 0600, atomic rename, dir 0700:
`{"provider","model","ctx_used_pct","ctx_left_tokens","ctx_size","session","cwd_base","ts"}`.
Never store keys, full paths, prompts or project names. The gauge shows only if `ts` is < `AGENT_TTL` (120 s) old.

## Gauge
`bin/agent-read.sh normal|warn|root`; env `AGENT_SHOW=pct|tokens|bar`, `AGENT_WARN_AT=70`, `AGENT_ROOT_AT=90`.
Set in the `[custom.agent*]` commands of `starship/starship.toml`.

## Claude Code
`install.sh --with claude-code` sets only the `statusLine` key to `adapters/claude-code/statusline.sh`.
If a `statusLine` command existed, it is saved to `~/.config/prompt-kit/inner-statusline`; the adapter runs it
on the same stdin and appends the gauge to its output. First run dumps the stdin JSON to
`~/.cache/agent-status/claude-code.raw.json` to verify field names on your version. Remove: restore `settings.json.bak.*`.

## Other providers
Add an adapter only if the CLI exposes a hook/status event. Codex / Gemini / OpenCode / Cursor: not checked yet.
"Until compact" (`compact_at`): not implemented, waits for a verified raw.json.
