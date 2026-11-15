# Agents
## State contract
One file per session: `~/.cache/agent-status/<provider>.<session>.json`, mode 0600, atomic rename, dir 0700:
`{"provider","model","ctx_used_pct","ctx_left_tokens","ctx_size","session","cwd","pid","ts"}`.
`cwd` is the full path (needed for matching; the file is 0600 and never leaves the machine). No keys, prompts or project names.
Files without `<session>` (legacy `<provider>.json`) and `*.raw.json` are ignored by the reader.

## Gauge
`bin/agent-read.sh normal|warn|root`. Parameters live in `~/.config/prompt-kit/agent.env` (`KEY=VALUE`, parsed not executed;
an env var of the same name wins; read by the reader and the adapter; `install.sh` creates it with defaults, never overwrites):
- `AGENT_SHOW=pct|tokens|bar|compact` (`compact` = `N% to compact`), `AGENT_WARN_AT=70`, `AGENT_ROOT_AT=90`
- `AGENT_TTL=300`: a session counts only if `ts` is younger than this **and** `kill -0 pid` succeeds.
- `AGENT_SCOPE=cwd|any`: `cwd` = only sessions whose cwd contains the shell's `$PWD` or is inside it (sessions in `/` are ignored); `any` = all live sessions.
- `AGENT_COMPACT_AT=95`: Claude Code's JSON has no compact-threshold field, so this is a configured value; the adapter stores `ctx_to_compact_pct` in the state file.
- 1 matching session: `◰ 42% ◆ opus`. More: `◆ 2× ◰ 75%` (worst percentage, level by the worst).

## Cleanup
SessionEnd hook `adapters/claude-code/session-end.sh` deletes the session's file; the statusline adapter also removes
files whose pid is dead (crash / kill -9). `install.sh --with claude-code` adds the hook and removes the legacy `claude-code.json`.

## Claude Code
`install.sh --with claude-code` sets the `statusLine` key to `adapters/claude-code/statusline.sh` and adds the SessionEnd hook.
The adapter prints a status line built from **segments**, configured in `~/.config/prompt-kit/statusline.env`:
- `SEGMENTS="model ctx cwd git cost gauge"`: ordered tokens, empty output is skipped.
  Native: `model ctx cwd git cost gauge`. `inner` = the one command in `INNER_COMMAND`. `ext` = every executable in
  `~/.config/prompt-kit/segments.d/` (sorted; gets the session JSON on stdin, prints text, 3 s timeout).
  A leading `~` runs the segment but hides its output (keeps a side-effect script running).
- `SEP=" · "` joins the parts. `INNER_COMMAND=...` is the old wrapper command (kept for one-liners).
- Migration: an existing `inner-statusline` becomes `INNER_COMMAND` with `SEGMENTS="inner gauge"`, `SEP=" "` (output unchanged; the old file is kept).
  On this machine the uptime-board script is `segments.d/10-uptime.sh` with `SEGMENTS="ext gauge"`.
- The adapter never fails: no `set -e`, every segment is guarded, it always prints one line.
`pid` is the nearest ancestor process named `claude`. First run dumps the stdin JSON to `~/.cache/agent-status/claude-code.raw.json`
to verify field names on your version. Remove: restore `settings.json.bak.*`.

## Other providers
Add an adapter only if the CLI exposes a hook/status event. Codex / Gemini / OpenCode / Cursor: not checked yet.
