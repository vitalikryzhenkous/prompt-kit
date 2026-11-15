# Agents
## State contract
One file per session: `~/.cache/agent-status/<provider>.<session>.json`, mode 0600, atomic rename, dir 0700:
`{"provider","model","ctx_used_pct","ctx_left_tokens","ctx_size","ctx_to_compact_pct","session","cwd","pid","ts"}`.
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
SessionEnd hook `adapters/claude-code/session-end.sh` deletes the session's file, then runs every executable in `~/.config/prompt-kit/session-end.d/`
(sorted; the hook JSON on stdin, `PROMPT_KIT_FINAL=1`, 3 s timeout each, output ignored). Example: a script that sends the final session state to your own dashboard:
```
#!/usr/bin/env bash
# ~/.config/prompt-kit/session-end.d/50-report.sh   (chmod +x)
sid=$(jq -r .session_id)
curl -fsS -m 2 -X POST "$MY_ENDPOINT" -d "{\"session\":\"$sid\"}" >/dev/null
```
The statusline adapter also removes
files whose pid is dead (crash / kill -9). `install.sh --with claude-code` adds the hook and removes the legacy `claude-code.json`.

## Claude Code
`install.sh --with claude-code` sets the `statusLine` key to `adapters/claude-code/statusline.sh` and adds the SessionEnd hook.
The adapter prints a status line built from **segments**. The list is `STATUSLINE_SEGMENTS` in `~/.config/prompt-kit/agent.env`;
the separator and the wrapped command (`SEP`, `INNER_COMMAND`) are in `~/.config/prompt-kit/statusline.env`.
- `STATUSLINE_SEGMENTS="model cwd git ctx"` (default; `cost`, `ext`, `inner` are opt-in; legacy `SEGMENTS` in `statusline.env` is used only if it is unset): ordered tokens, empty output is skipped.
  Native: `model cwd git ctx cost` (`ctx` = `◰ N%`, `gauge` is an alias). `inner` = the one command in `INNER_COMMAND`. `ext` = every executable in
  `~/.config/prompt-kit/segments.d/` (sorted; gets the session JSON on stdin, prints text; 3 s timeout each, and scripts after the first 4 s in total are skipped).
  A leading `~` runs the segment but hides its output (keeps a side-effect script running).
- `SEP=" · "` joins the parts. Values are trimmed at the edges: quote a value that starts or ends with a space (`SEP=" | "`). `INNER_COMMAND=...` is the old wrapper command (kept for one-liners).
- Migration: an existing `inner-statusline` becomes `INNER_COMMAND` with `SEGMENTS="inner gauge"`, `SEP=" "` (output unchanged; the old file is kept).
- The adapter never fails: no `set -e`, every segment is guarded, it always prints one line.
`pid` is the nearest ancestor process named `claude`. First run dumps the stdin JSON to `~/.cache/agent-status/claude-code.raw.json`
to verify field names on your version. Remove: `bin/uninstall.sh` (takes out only our `statusLine` and `SessionEnd` entries; see README).

## Other providers
Add an adapter only if the CLI exposes a hook/status event. Codex / Gemini / OpenCode / Cursor: not checked yet.

## Icons
`bin/theme.sh icon <directory|git_branch|nodejs|time|username> <glyph | nf-<set>-<name> | U+XXXX>` rewrites the icon in that module's
`format` in `starship/starship.toml`. `nf-` names resolve through Nerd Fonts `glyphnames.json` (version and sha256 pinned in
`bin/versions.env`, cached in `~/.cache/prompt-kit/`). A `U+` code is used as given and is not checked against any name.
`bin/check-icons.sh` (run by `doctor.sh` and `preview.sh`) fails if a module format has no glyph.
