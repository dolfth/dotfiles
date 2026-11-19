Look for problems in Home Assistant. Change nothing in HA. No one is available
to answer questions. Finish with the report described at the end.

## API

- Use the token in `.ha_token` in this folder. The base URL is `$HA_URL`.
  Never print the token.
- Allowed:
  - GET requests
  - `POST /api/template`
  - read-only WebSocket commands (`*/list`, `*/get`, e.g.
    `config/entity_registry/list`, `repairs/list_issues`, `trace/list`).
    `$HA_PY` is a python3 with the `websockets` module for this.
- No service calls, and no other POSTs or WebSocket commands.
- HA also serves the MCP endpoint at `$HA_URL/api/mcp` (read-only by its
  config entry). It is stateless: one JSON-RPC POST per call, no session,
  so curl reaches it without an MCP client:

  ```sh
  mcp() { curl -fsS -X POST -H @<(printf 'Authorization: Bearer %s\n' "$(< .ha_token)") \
    -H 'Content-Type: application/json' -H 'Accept: application/json' \
    -H 'MCP-Protocol-Version: 2025-06-18' -d "$1" "$HA_URL/api/mcp"; }
  mcp '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
  mcp '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"system_log__get_entries","arguments":{"level":"error","limit":5}}}'
  ```

  Prefer `system_log__get_entries` and `history__get_history` to guessing
  from `/api/states`; the server filters every tool to read-only, so the
  contract -- change nothing -- holds even if a tool is misjudged.

The sandbox only lets this run reach Home Assistant and the model server;
anything else you curl dies with a proxy denial -- that is the sandbox
working, not an HA problem.

## What to look for

- Devices that dropped off: a device whose entities are all `unavailable`.
- Frozen sensors: measurement sensors whose `last_reported` is old.
- Misfiring automations: errors in traces or the log; running far more often
  than they should; never running; broken configuration.
- Integrations that are unused (no entities, nothing refers to them) or
  misconfigured (not loaded, retrying, repeating errors in the log).
- Anything else that looks wrong: open repairs, errors in the log, entities
  with impossible values, and so on.

Noise includes battery devices that sleep, sensors whose value does not
change, and seasonal automations.

## Notes

`monitor-notes.md` in this folder holds your notes from earlier runs. Read it
first. Rewrite it as you go, not only at the end, so a run that is killed
still leaves its findings. It holds:

- the open problems, with the date each one was first seen
- the findings you judged to be noise, with the reason

Drop problems that have been resolved. Write no other file besides the report
draft.

## Report

Your last message is sent as a phone notification in Markdown. Keep it under
1500 characters and add no preamble.

Report only new problems. Known open problems are in the notes and are not
repeated.

- Line 1: the verdict, e.g. "2 new problems."
- One bullet per new problem: what it is, since when, the likely cause, and
  the fix.
