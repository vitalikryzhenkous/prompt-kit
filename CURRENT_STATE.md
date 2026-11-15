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
- [x] п.4 пилюли: вариант B применён; dir+branch+status в одной пилюле, username в user_bg, pill/user_bg — токены палитры
## Правила тестирования
- Отчётные сегменты (90-uptime-report.sh, всё, что пишет на board / в ~/.uptime) тестировать только с переопределённым путём: `UPTIME_REPORT_CMD=<заглушка>` (statusline.py не поддерживает UPTIME_LOG: путь ~/.uptime/sessions.jsonl зашит), `XDG_CACHE_HOME` и `AGENT_STATUS_DIR` — в scratchpad. Реальные логи и board не трогать.
- SessionEnd: хук после удаления state-файла вызывает 90-uptime-report.sh с UPTIME_REPORT_MIN_S=0 UPTIME_REPORT_FINAL=1; финальное состояние берётся из сохранённого последнего JSON сессии (в payload хука нет context_window).
## Queue
- [x] п.6 theme.sh icon (глифы dir/branch/node/time восстановлены, username = md-robot_excited)
- [x] guard: bin/check-icons.sh в doctor и preview (+ негативный тест); ловит регрессию 107d977
- [x] statusline: сегменты через STATUSLINE_SEGMENTS (agent.env); ctx = ◰ N%; uptime-board убран из строки (limits → segments.d/20-limits.sh, отчёт на board → hidden 90-uptime-report.sh)
- [x] default STATUSLINE_SEGMENTS="model cwd git ctx" (cost opt-in); 90-uptime-report.sh: троттлинг 30 с + фон (statusline.py уже дедуплицирует по изменению)
- [x] п.7.1 PROMPT_KIT_DIR; п.7.2 WSL-only + WT профиль по имени дистрибутива; п.7.3 deps+hints; п.7.4 uninstall.sh (roundtrip в fake HOME: bashrc и settings.json идентичны оригиналу); п.7.5 README + doctor --report
- [~] п.6 сегменты + agent.env: код, тесты и ревью opus (8 находок исправлены, 426ada3) готовы; мерж по твоему указанию (agent.env, statusline.env, segments.d, INNER_COMMAND; uptime = segments.d/10-uptime.sh; вывод идентичен)
- [ ] theme.sh (color|palette|layout|move|agent) + palettes nord, dracula, mono + layouts (split, left, minimal, oneline, rightprompt)
- [ ] compact_at: implement fields verified; no explicit compact-threshold field in raw.json, so the threshold stays a config value (default 95) — owner to confirm
- [ ] install.ps1 / doctor.ps1 (Windows native), macOS/zsh — not needed for WSL
