Install the pending Home Assistant updates. No one is available to answer
questions. Finish with the report described at the end.

## API

- Use the token in `.ha_token` in this folder. The base URL is `$HA_URL`.
  Never print the token.
- A pending update is an `update.*` entity with state `on`.
- Install: `POST /api/services/update/install` with
  `{"entity_id": "<id>", "backup": true}`. Leave out `backup` if
  `supported_features & 8` is 0.
- `skipped_version` set means the user chose to skip: do not install, and
  never call `update.skip` or `update.clear_skipped`.
- `update.install` is the only service you call. Never restart HA, change
  configuration or restore backups.
- The sandbox only lets this job reach HA and the model server; other curls
  die with proxy 403/502 -- the sandbox working, not an HA problem.

## Order

One at a time:

1. `update.home_assistant_supervisor_update`
2. `update.home_assistant_core_update`
3. Add-ons
4. HACS and other custom integrations
5. Device firmware
6. `update.home_assistant_operating_system_update`

Supervisor, Core and OS installs restart HA. The API is down for a few
minutes while that happens.

## Procedure

1. Save `GET /api/states` before the first install.
2. Before each install read `release_summary`, and `release_url` if it is
   reachable. Skip the update if the notes show a breaking change for an
   integration in `GET /api/config` -> `components`, or a needed manual
   step. If the notes cannot be read, install anyway. `AGENTS.md` in this
   folder outranks your judgement: its written decisions are not bugs to
   fix.
3. Poll the entity every 30 s until `in_progress` is false and the state is
   `off`. Allow at most 20 min, or 45 min for device firmware.
4. After Supervisor, Core or OS: wait until `GET /api/` answers (at most
   10 min), then wait another 60 s before trusting any `unavailable` -- a
   fresh restart answers 200 before integrations are warm. Then compare
   `GET /api/states` with the saved states.
5. Stop installing if an update fails or times out, if the API does not
   come back, or if entities that worked before are now `unavailable`.
   Do not fix: report.

## Time

Start no install in the last 30 minutes before you are killed.

## Report

Your last message is sent as a phone notification in Markdown. Keep it under
1500 characters and add no preamble.

- Line 1: the verdict, e.g. "All 6 updates installed." or "Stopped after
  Core failed."
- One bullet per update: title, old -> new version, and one of: installed,
  skipped (reason), failed (what happened), not reached.
- If any action is needed, end with one line saying what it is.
- If nothing was pending, your entire last message is: No updates needed.
