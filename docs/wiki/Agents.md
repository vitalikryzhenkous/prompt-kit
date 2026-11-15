# Agents
## State contract
One file per session: `~/.cache/agent-status/<provider>.<session>.json`, mode 0600, atomic rename, dir 0700:
`{"provider","model","ctx_used_pct","ctx_left_tokens","ctx_size","session","cwd","pid","ts"}`.
`cwd` is the full path (needed for matching; the file is 0600 and never leaves the machine). No keys, prompts or project names.
Files without `<session>` (legacy `<provider>.json`) and `*.raw.json` are ignored by the reader.

## Gauge
`bin/agent-read.sh normal|warn|root`; env set in the `[custom.agent*]` commands of `starship/starship.toml`:
- `AGENT_SHOW=pct|tokens|bar`, `AGENT_WARN_AT=70`, `AGENT_ROOT_AT=90`
- `AGENT_TTL` (agent.ttl, default 300): a session counts only if `ts` is younger than this **and** `kill -0 pid` succeeds.
- `AGENT_SCOPE` (agent.scope, default `cwd`): `cwd` = only sessions whose cwd contains the shell's `$PWD` or is inside it
  (so a shell in the project, a subfolder, or the parent of the project sees it); `any` = all live sessions.
- 1 matching session: `◰ 42% ◆ opus`. More: `◆ 2× ◰ 75%` (worst percentage, level by the worst).

## Cleanup
SessionEnd hook `adapters/claude-code/session-end.sh` deletes the session's file; the statusline adapter also removes
files whose pid is dead (crash / kill -9). `install.sh --with claude-code` adds the hook and removes the legacy `claude-code.json`.

## Claude Code
`install.sh --with claude-code` sets only the `statusLine` key to `adapters/claude-code/statusline.sh`.
If a `statusLine` command existed, it is saved to `~/.config/prompt-kit/inner-statusline`; the adapter runs it
on the same stdin and appends the gauge to its output. `pid` is the nearest ancestor process named `claude`. First run dumps the stdin JSON to
`~/.cache/agent-status/claude-code.raw.json` to verify field names on your version. Remove: restore `settings.json.bak.*`.

## Other providers
Add an adapter only if the CLI exposes a hook/status event. Codex / Gemini / OpenCode / Cursor: not checked yet.
"Until compact" (`compact_at`): not implemented, waits for a verified raw.json.
