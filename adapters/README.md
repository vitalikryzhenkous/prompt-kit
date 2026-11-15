# Adapter contract
Write `~/.cache/agent-status/<provider>.json` (0600, atomic rename):
`{"provider","model","ctx_used_pct","ctx_left_tokens","ctx_size","session","cwd_base","ts"}`.
No keys, full paths, prompts or project names. Add an adapter only if the CLI exposes a hook/status event.
