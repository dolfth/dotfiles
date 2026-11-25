# AGENTS

- README updates are for the human: write the facts, the human rewrites
  the prose.
- Same restraint in comments and commit messages: what and why, few
  lines, no session backstory.
- Same for status reports to the human: short sentences, one fact each,
  plain words; no nested clauses, no dash-pileups, tables only for real
  comparisons.
- Check the mise release notes now and then for features this repo could
  use, and bump the floor in mise.toml when one is worth pinning.
  Last checked: 2026.11.9 (2026-11-17).
- Bumping the floor breaks every host below it: mise.toml is the global
  config, so a too-old mise refuses every command on that host until it
  upgrades. Order: upgrade mise on every host (`up`, brew), then commit
  the bump. CI installs mise at the floor, so the bump also moves what
  CI proves.
- Docs layout: README is the manual (bootstrap, day to day, fleet);
  notes/ is the reference (files, tasks, sandbox, services, pitfalls).
  A new fact goes into its notes file, the README only gains a line
  when using the repo needs it.
