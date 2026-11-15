# CURRENT_STATE — prompt-kit
## Done
- [x] init: config + preview (789284d)
- [x] install.sh / doctor.sh / README / Agents.md (883cebb)
- [x] real install --with claude-code; doctor all PASS; raw.json fields verified (used_percentage, remaining_percentage, context_window_size, model.display_name, workspace.current_dir, session_id)
## Branch feature/fixes-and-per-cwd
- [x] п.1 git_status format (fe9f453)
- [x] п.2 directory glyph: U+F07B уже в формате, правок нет
- [x] п.3 gauge: claude-code.json обновляется живьём (ts=now), TTL 120; визуально — после рестарта у владельца
- [x] п.5 Agent per cwd: per-session files, reader scope cwd|any, ttl 300 + kill -0, SessionEnd hook, install.sh (hook + legacy removal), preview 2 sessions × 2 scopes. Tested: adapter pid=claude, child/sibling cwd, dead pid, stale ts, hook delete, adapter cleanup
## Queue
- [ ] theme.sh (color|palette|layout|move|agent) + palettes nord, dracula, mono + layouts (split, left, minimal, oneline, rightprompt)
- [ ] compact_at: implement fields verified; no explicit compact-threshold field in raw.json, so the threshold stays a config value (default 95) — owner to confirm
- [ ] install.ps1 / doctor.ps1 (Windows native), macOS/zsh — not needed for WSL
