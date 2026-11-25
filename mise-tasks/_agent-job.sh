# shellcheck shell=bash
# shellcheck disable=SC2154  # the parameters below are assigned by the sourcing job
# Shared harness for gza's scheduled omp agent jobs: ha-monitor, ha-update
# and nwa-health. Each job script sets the parameters, defines the hooks,
# and calls agent_main. What lives here is the invariant the port kept from
# nwa's systemd unit pairs (see the per-job headers for the deltas):
#
# - the state machine: $state holds started, skipped, quiet, summary.md,
#   result, failures, and the runs/<ts>/ archives (30 days). The agent gets
#   no write there at all: it could otherwise rewrite the result the report
#   reads.
# - the heartbeat: one dated line per run in ~/Library/Logs/<job>.log in the
#   format "%Y-%m-%d %H:%M <job> <msg>" -- check leg 5 parses these.
# - archive on every exit (nwa's ExecStopPost): a preflight skip is still a
#   run, so runs/ holds every attempt and the stale check has truth.
# - the watchdog: launchd has no TimeoutStartSec. A background agent plus a
#   kill loop is the kill switch, and the killed marker keeps a timeout
#   distinguishable from a crash in the report.
# - the report: an unsandboxed ntfy leg, silent on a quiet success, loud
#   once on a new failure, de-prioritized while one persists, loud again on
#   recovery.
#
# Parameters every job sets before calling agent_main:
#   job_name        the agent/log name (ha-monitor); also the ntfy title
#   repo_label      preflight message prefix ("HA repo", "nixos-config")
#   repo_dir        the context repo that must exist and be readable
#   state           ~/.local/state/agent-jobs/<job>
#   work            the agent's work dir (the context repo)
#   draft           the draft file the agent keeps in the final format
#   ntfy_file       the shared topic file
#   log             the heartbeat log under ~/Library/Logs
#   model           the model pinned for this job
#   timeout_min     watchdog limit in minutes
#   quiet_answer    the exact last message that means "nothing to report"
#   quiet_norm      quiet_answer stripped of whitespace and asterisks
#
# Parameters with a default:
#   stale_days=1    the report's stale window (the ha-update job: 8)
#   notes, notes_limit   set when the job keeps cross-run notes; the report
#                        then also audits that the notes were rewritten
#   profile_base=$repo/nono/omp.json   the profile the job profile derives from
#   nono_mode=run   run (supervised: the network allow-list filters) or wrap
#                   (no proxy; ssh survives -- the nwa-health shape)
#   usage_extra     appended to the usage line for the job's own subcommands
#
# Hooks the job defines:
#   job_preflight   reachability and secret checks beyond the repo probe;
#                   to skip the run: write $state/skipped and exit 0
#   job_profile     print the generated nono profile for this job to stdout
#   job_setup       job-specific exports and fixtures (runs after the
#                   common tool PATH/TMPDIR/Bun cache are exported)
#   job_prompt      print the agent prompt
#
# The report's dry-run switch derives from the job name: uppercase,
# dashes to underscores, _DRYRUN appended (HA_MONITOR_DRYRUN, ...).

agent_heartbeat() { # one dated line per run: check leg 5 parses these
  mkdir -p "$(dirname "$log")"
  printf '%s %s %s\n' "$(date '+%Y-%m-%d %H:%M')" "$job_name" "$1" >>"$log"
  if [ "$(wc -l <"$log")" -gt 250 ]; then
    tail -n 200 "$log" >"$log.tmp" && mv "$log.tmp" "$log"
  fi
}

# The archive mirrors nwa's ExecStopPost: it runs on every exit, including a
# preflight skip.
agent_archive() {
  local rc=$?
  local run f
  run="$state/runs/$(date -r "$(cat "$state/started" 2>/dev/null || date +%s)" +%F_%H%M)"
  mkdir -p "$run"
  for f in result skipped quiet summary.md agent.err; do
    [ -e "$state/$f" ] && cp -p "$state/$f" "$run/"
  done
  [ -e "$draft" ] && cp -p "$draft" "$run/"
  if [ -n "${notes:-}" ] && [ -e "$notes" ]; then cp -p "$notes" "$run/"; fi
  find "$state/runs" -mindepth 1 -maxdepth 1 -mtime +30 -exec rm -rf {} + 2>/dev/null
  if [ -e "$state/skipped" ]; then
    agent_heartbeat "skipped: $(head -c 120 "$state/skipped" | tr '\n' ' ')"
  elif [ "$(cut -d' ' -f1 "$state/result" 2>/dev/null)" = success ]; then
    agent_heartbeat "ok: $(grep -m1 -v '^[[:space:]]*$' "$state/summary.md" 2>/dev/null | head -c 120)"
  else
    agent_heartbeat "failed: $(cat "$state/result" 2>/dev/null || echo "no result (killed) rc=$rc")"
  fi
}

# The HA reachability preflight shared by both HA jobs: the token file and
# one API call. The token goes to curl on a file descriptor, never in the
# environment or argv.
agent_ha_preflight() {
  if [ ! -r "$token" ]; then
    echo "no HA token at $token -- copy it from nwa: scp nwa:Documents/code/homeassistant/.ha_token $token" \
      >"$state/skipped"
    exit 0
  fi
  if ! curl -fsS -m 60 -H @<(printf 'Authorization: Bearer %s\n' "$(< "$token")") \
      "$ha_url/api/" >/dev/null 2>"$state/skipped"; then
    echo "Home Assistant API not reachable at $ha_url" >>"$state/skipped"
    exit 0
  fi
  rm -f "$state/skipped"
}

agent_run() {
  mkdir -p "$state/runs"
  trap agent_archive EXIT
  rm -f "$state"/{skipped,quiet,summary.md,result,agent.err,killed}
  date +%s >"$state/started"

  # Preflight. The repo probe separates missing from unreadable: a launchd
  # job denied by TCC on ~/Documents sees EPERM where the terminal saw the
  # files. Job-specific reachability and secrets are job_preflight's.
  if [ ! -d "$repo_dir" ]; then
    echo "$repo_label missing at $repo_dir -- clone it or move the job's context elsewhere" \
      >"$state/skipped"
    exit 0
  fi
  repo_probe=$(ls "$repo_dir" 2>&1 >/dev/null)
  case $repo_probe in
    *"Operation not permitted"*)
      echo "$repo_label unreadable: Operation not permitted on $repo_dir -- TCC denies the launchd job ~/Documents (grant FDA to /bin/bash, or move the repo)" \
        >"$state/skipped"
      exit 0 ;;
  esac
  job_preflight

  # The job's nono profile, generated so it cannot drift from the base it
  # derives from, and validated before anything launches.
  job_profile >"$profile_out" || exit 1
  nono profile validate "$profile_out" >/dev/null || {
    echo "the generated job profile does not validate" >"$state/skipped"; exit 1; }

  # The sandboxed omp needs the same env the interactive wrappers export:
  # the tool PATH (the profile denies the shell configs that would set it),
  # the Bun cache under the granted ~/.omp, a granted temp dir. The job adds
  # its own in job_setup.
  PATH="$HOME/.local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin"
  export PATH
  TMPDIR="$HOME/.cache/nono-tmp/omp"
  mkdir -p "$TMPDIR"; export TMPDIR
  export BUN_INSTALL_CACHE_DIR="$HOME/.omp/cache/bun-install"
  job_setup

  local prompt
  prompt="$(job_prompt)"

  cd "$work" || {
    echo "cannot enter the work dir $work" >>"$state/skipped"; exit 0; }
  rm -f "$draft"
  nono "$nono_mode" --allow-cwd --profile "$profile_out" -- \
    /usr/local/bin/omp-unsandboxed -p --no-session --approval-mode=yolo \
    --model "$model" "$prompt" \
    >"$state/summary.md" 2>"$state/agent.err" &
  local job=$! elapsed=0 limit=$((timeout_min * 60)) rc=0
  # The kill switch: launchd has no TimeoutStartSec.
  while kill -0 "$job" 2>/dev/null && [ "$elapsed" -lt "$limit" ]; do
    sleep 10; elapsed=$((elapsed + 10))
  done
  if kill -0 "$job" 2>/dev/null; then
    : >"$state/killed"
    kill -TERM "$job" 2>/dev/null
    sleep 30
    kill -KILL "$job" 2>/dev/null
  fi
  wait "$job"; rc=$?

  if [ -e "$state/killed" ]; then
    echo "timeout $rc" >"$state/result"
  elif [ "$rc" -eq 0 ]; then
    echo "success $rc" >"$state/result"
    rm -f "$draft"
  else
    echo "failed $rc" >"$state/result"
  fi
  exit "$rc"
}

agent_report() {
  if [ ! -d "$state" ]; then
    echo "No state directory at $state -- the job has never run; mise run $job_name" >&2
    exit 1
  fi
  cd "$state" || exit 1
  local attention="" quiet="" finished="" ran=""
  local run="" failures recovered="" msg="" notes_err="" title="" priority=3
  local stale_text="24 hours" first
  [ "$stale_days" -gt 1 ] && stale_text="$stale_days days"

  if [ ! -e started ] || [ $(( $(date +%s) - $(<started) )) -gt $(( stale_days * 86400 )) ]; then
    run="did not run in the last $stale_text"; attention=1
  elif launchctl print "gui/$(id -u)/dev.mise.$job_name" 2>/dev/null \
      | grep -q 'state = running'; then
    run="still running"; attention=1
  elif [ -e quiet ]; then
    run="nothing to do ($(head -c 300 quiet))"; quiet=1
  elif [ -s skipped ]; then
    run="skipped: $(head -c 300 skipped)"; attention=1
  elif [ "$(cut -d' ' -f1 result 2>/dev/null)" = success ]; then
    run="finished"; finished=1; ran=1
    first=$(grep -m1 -v '^[[:space:]]*$' summary.md 2>/dev/null | tr -d '[:space:]*')
    [ "$first" = "$quiet_norm" ] && quiet=1
  else
    run="failed ($(cat result 2>/dev/null || echo "no result"))"; attention=1; ran=1
  fi

  # A run that keeps failing notifies loudly once, then quietly, and once
  # more when it recovers.
  failures=$(cat failures 2>/dev/null || echo 0)
  if [ -n "$attention" ]; then
    failures=$((failures + 1)); echo "$failures" >failures
    [ "$failures" -gt 1 ] && run="$run; $failures runs in a row"
  elif [ "${failures:-0}" -gt 0 ]; then
    run="$run; recovered after $failures failed runs"; recovered=1
    rm -f failures
    failures=0
  fi

  msg="**Run:** $run"

  # Small models say they updated a file without doing it. Jobs with no
  # notes file have nothing to audit (notes_err stays empty everywhere).
  if [ -n "$ran" ] && [ -n "${notes:-}" ]; then
    if [ ! "$notes" -nt started ]; then
      notes_err="not rewritten in this run"
    elif [ "$(wc -c <"$notes" 2>/dev/null || echo 0)" -gt "$notes_limit" ]; then
      notes_err="$(wc -c <"$notes") characters, over the limit of $notes_limit"
    fi
    [ -n "$notes_err" ] && msg="$msg"$'\n\n'"**Notes:** $notes_err"
  fi

  if [ -n "$quiet" ] && [ -z "$attention" ] && [ -z "$recovered" ] && [ -z "$notes_err" ]; then
    echo "$msg"
    echo "Nothing to report; no notification."
    exit 0
  fi

  if [ -s summary.md ] && [ -n "$finished" ]; then
    msg="$msg"$'\n\n'"**Agent:**"$'\n'"$(head -c 2000 summary.md)"
  elif [ -s "$draft" ] && [ "$draft" -nt started ]; then
    msg="$msg"$'\n\n'"**Agent's draft (unfinished):**"$'\n'"$(head -c 2000 "$draft")"
  fi

  if [ "${failures:-0}" -gt 1 ]; then
    title="$job_name: still failing"; priority=2
  elif [ -n "$attention" ]; then
    title="$job_name: needs attention"; priority=4
  else
    title="$job_name"; priority=3
  fi

  local dry_var
  dry_var="$(printf '%s' "$job_name" | tr '[:lower:]-' '[:upper:]_')_DRYRUN"
  if [ "${!dry_var:-}" = 1 ]; then
    printf 'dry-run (title: %s, priority: %s):\n%s\n' "$title" "$priority" "$msg"
    exit 0
  fi
  if [ ! -r "$ntfy_file" ]; then
    echo "no ntfy topic at $ntfy_file -- copy it from nwa (sops secret ntfy_topic)" >&2
    exit 1
  fi
  printf '%s' "$msg" | head -c 3900 | curl -fsS \
    -H "Title: $title" -H "Priority: $priority" -H "Markdown: yes" \
    --data-binary @- \
    "https://ntfy.sh/$(<"$ntfy_file")"
}

agent_main() {
  : "${stale_days:=1}" "${nono_mode:=run}"
  : "${profile_out:=$state/job.json}" "${profile_base:=$repo/nono/omp.json}"
  declare -f job_preflight >/dev/null 2>&1 || job_preflight() { :; }
  declare -f job_setup >/dev/null 2>&1 || job_setup() { :; }
  case "${1:-run}" in
    run) agent_run ;;
    report) agent_report ;;
    # The generated profile alone, for the eye and for drift checks -- the
    # same jq agent_run feeds the sandbox, with no job launched.
    profile) job_profile ;;
    *) echo "usage: mise run $job_name [run|report${usage_extra:-}]" >&2; exit 2 ;;
  esac
}
