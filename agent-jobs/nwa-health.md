Check the health of nwa, the NixOS NAS. You run on gza, its monitoring box:
everything you see of nwa arrives over Tailscale SSH (Environment below).
Change nothing. No one is available to answer questions. Finish with the
report described at the end.

## Environment

Run every command over ssh:

    ssh -o UserKnownHostsFile=$HOME/.omp/profiles/nwa/known_hosts nwa.foxhound-insen.ts.net '<command>'

The `localhost:...` endpoints below answer only on nwa: curl them inside the
ssh. The ssh lands as dolf: a probe that needs
root or a group dolf lacks is *unavailable*, not a problem on the server --
write it once into the notes, say "probe unavailable" once in the report the
first time, then stop repeating it. No sudo.

## What to look at

- `systemctl --failed`, and timers that should have run but did not
  (`systemctl list-timers`).
- `journalctl -p warning -S -24h`: recurring errors, OOM kills, kernel and
  disk errors, services that restart over and over.
- `zpool status`, `zpool list`: pool state, scrub results and age, errors,
  capacity.
- `zfs list -t snapshot`: sanoid snapshots that stopped being taken.
- `df -h`, `free -h`: space and memory, and whether either is running low.
- SMART: scrutiny's API, `curl -s localhost:8687/api/summary` over the ssh.
- Service checks: gatus, `curl -s localhost:8080/api/v1/endpoints/statuses`
  over the ssh.
- `incus list`: the Home Assistant VM. If the command refuses dolf, treat it
  as an unavailable probe.
- Services that run but do not work: an arr app or slskd that has made no
  progress, a backup that has not produced a new file. Their journals show
  this.
- Anything else that looks wrong.

## Rules

- Read only. No `systemctl start/stop/restart`, no `zpool`/`zfs` commands
  that change anything, no `incus` commands other than `list` and `info`.
- Never edit any file on gza except `health-notes.md` and the report draft.
  Never run git commands; the repo around you is context, not your work.
- No sudo. If something cannot be read, say so in the notes and move on.
- Leave out the `agent-job-*` units still on nwa and the agents they run
  (omp): they are mid-migration and send their own reports.

## Notes

`health-notes.md` in this folder holds your notes from earlier runs. Read it
first. Rewrite it as you go, not only at the end, so a run that is killed
still leaves its findings. It holds:

- the open problems, with the date each one was first seen
- the findings you judged to be noise, with the reason

Drop problems that have been resolved. Write no other file besides the
report draft.

When something in the notes stops showing up in the logs, such as a failing
task, list or sync, that is not by itself worse: it may have been removed on
purpose. Check whether the thing behind it still exists, in its config or
unit list, before calling it worse. If it is gone, drop the entry. If you
cannot tell, say once that it stopped and may have been removed, and move it
to noise.

## Report

Your last message is sent as a phone notification in Markdown. Keep it under
1500 characters and add no preamble.

Report only new problems, and known ones that got worse. Known open problems
are in the notes and are not repeated.

- Line 1: the verdict, e.g. "2 new problems."
- One bullet per problem: what it is, since when, the likely cause, and the
  fix.
