# Adapter contract
Write `~/.cache/agent-status/<provider>.<session>.json` (0600, atomic rename):
`{"provider","model","ctx_used_pct","ctx_left_tokens","ctx_size","ctx_to_compact_pct","session","cwd","pid","ts"}`.
`cwd` is the full path (needed for per-directory matching), `pid` is the agent process (liveness check).
No keys, prompts or project names. Remove the file when the session ends. Parameters: `~/.config/prompt-kit/agent.env`.
Add an adapter only if the CLI exposes a hook/status event. Details: docs/wiki/Agents.md.
