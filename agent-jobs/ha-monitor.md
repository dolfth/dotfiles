Look for problems in Home Assistant. Change nothing in HA. No one is available
to answer questions. Finish with the report described at the end.

## Ground rules

- The only files you write are `monitor-notes.md` and `report-draft.md` in
  this folder.
- This folder is a git repo: the config that runs on HA, plus the user's own
  findings. Consult it before concluding anything:
  - `AGENTS.md`, "Gotchas": known, accepted or deliberately-unfixed problems
    with dates and decisions, and how the system is wired. A match there is
    not a new problem, and a fix you would suggest that contradicts a written
    decision is wrong.
  - `git log --since="<end of last run>" --stat`: commits from yesterday close
    or explain open notes. `docs:` messages ARE the user's findings; a
    `state: "v..."` bump is an upstream package update.
  - If reality contradicts a note, reality wins: update the note.
- Tag every claim not directly observed in API/log output `[inference]`.
  The user tests hypotheses himself; overstating costs trust.

## API

- Token in `.ha_token` here; base URL `$HA_URL`. Never print the token.
- Allowed: GET; `POST /api/template`; `POST /api/mcp`; read-only WebSocket
  commands (`*/list`, `*/get`). No service calls, no other POSTs, no mutation.
- Preferred route -- stateless, one curl per call:

  ```sh
  mcp() { curl -sS -X POST -H "Authorization: Bearer $(cat .ha_token)" \
    -H 'Content-Type: application/json' -H 'Accept: application/json' \
    -H 'MCP-Protocol-Version: 2025-06-18' -d "$1" "$HA_URL/api/mcp"; }
  mcp '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
  ```

  Read-only tools: `system_log__get_entries` (errors/warnings by level),
  `hassio__get_logs` (full window, `contains:`), `history__get_history`,
  `config__get_config_entries` (loaded/error), `search__search`,
  `homeassistant__render_template`. A 404 on `tools/list` means the
  mcp_server entry is gone -- fall back to REST + WS with `$HA_PY`/websockets.
- Freshness in one call: `POST /api/template` over `states`, listing entities
  with `as_timestamp(now()) - as_timestamp(state.last_reported) > 26 h`.
- The sandbox only lets this job reach HA and the model server; other curls
  die with proxy 403/502 -- the sandbox working, not an HA problem.

## Sweep, in this order

1. **Reachability.** Proxy 502 / dead on every path = HA or the host is down.
   That is the entire finding: notes entry with last proof of life, report,
   draft -- stop. Never spend > 10 min on an unreachable host.
2. **Log.** Errors and warnings grouped by logger since the last run. Drop
   lines the notes or AGENTS.md call noise; a new logger is a new candidate.
3. **Freshness.** The one-pass states scan, minus the notes' static list.
4. **Config entries + repairs.** Not-loaded/error entries, open issues.
5. **Automations.** Per id: recent traces, error counts, runs/hour,
   `last_triggered` sanity. `trace/list` needs
   `{"domain":"automation","item_id":"<id>"}`.
6. **Cross-check.** Re-verify each open notes problem: recovered -> drop it;
   materially worse -> it becomes reportable. Check git/AGENTS for closures.

## Judging

- Problems: entities all `unavailable`, sensors stopped reporting, automations
  erroring / runaway / never firing, entries not loaded or retrying, open
  repairs, impossible values.
- Noise: sleeping battery devices, legitimately static sensors, seasonal
  automations, your own probes' API errors, everything in the notes' noise
  list and AGENTS.md Gotchas.
- Root cause beats symptom: several symptoms sharing a cause = one bullet.

## Notes

`monitor-notes.md` is your memory between runs. Read it first; rewrite as
you go, not only at the end, so a killed run still leaves its findings.
Sections:

- **Open problems**: first seen, last confirmed, evidence (counts,
  entity_ids), cause `[observed]`/`[inference]`, fix consistent with
  AGENTS.md decisions.
- **Minor / watch**: not reportable yet; re-check next run.
- **Noise**: finding + why. Never re-litigate.
- **Environment**: endpoints and API quirks that cost you time -- write them
  down so the next run does not rediscover them.
- **Last run**: one line, date + coverage (full / partial: what was missed).

Drop resolved problems -- measured or committed. No victory log.

## Report

Your last message is sent as a phone notification in Markdown. Under 1500
characters, no preamble, no tables or code blocks. Report only new problems;
known ones live in the notes and are not repeated.

- Line 1: verdict, e.g. "2 new problems." or "1 new problem (HA DOWN)."
- At most 5 bullets, worst first: entity/device, since when, likely cause,
  fix.
- A material change to a known problem may appear once, marked "(worse)".
