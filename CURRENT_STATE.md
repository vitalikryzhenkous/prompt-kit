# CURRENT_STATE — prompt-kit
## Done
- [x] init: config + preview (789284d)
- [x] install.sh / doctor.sh / README / Agents.md (883cebb)
- [x] real install --with claude-code; doctor all PASS; raw.json fields verified (used_percentage, remaining_percentage, context_window_size, model.display_name, workspace.current_dir, session_id)
## Queue
- [ ] theme.sh (color|palette|layout|move|agent) + palettes nord, dracula, mono + layouts (split, left, minimal, oneline, rightprompt)
- [ ] compact_at: implement fields verified; no explicit compact-threshold field in raw.json, so the threshold stays a config value (default 95) — owner to confirm
- [ ] install.ps1 / doctor.ps1 (Windows native), macOS/zsh — not needed for WSL
