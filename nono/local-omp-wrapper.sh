#!/bin/sh
# The offline omp for sensitive work: installed as /usr/local/bin/local-omp (root:wheel
# 755) by `mise run dev-agents` (__BREW_PREFIX__ substituted at install). Same stack as
# omp-wrapper.sh, four differences: the generated offline profile, supervised execution
# (tail note), the omp named profile for state, private scratch.
#
# Offline: the allow-list holds only the model host (vars.omp_base -- 127.0.0.1 on gza,
# the tailnet FQDN elsewhere). Web tools, git push and package downloads die; that is the
# feature. The filter is per-host, so on gza every local port is inside the grant: the
# other loopback services (the server UIs, syncthing's API) are reachable too.
#
# State: OMP_PROFILE=local moves omp's whole user base to ~/.omp/profiles/local, which
# the daily profile denies, so sensitive facts cannot resurface in a networked session's
# memory, sessions or logs. Scratch lives in that tree too. The name is deliberate:
# herdr's detection does not claim local-omp as an omp session; HERDR_AGENT labels it.
export HERDR_AGENT=local-omp
export OMP_PROFILE=local

# Scratch and the nono capability manifest stay under the profile tree.
# XDG_CACHE_HOME stays shared: caches hold runtime material, never doc content -- but
# keep docs in $TMPDIR anyway.
: "${XDG_CACHE_HOME:=$HOME/.cache}"
TMPDIR="$HOME/.omp/profiles/local/tmp"
mkdir -p "$TMPDIR"
export TMPDIR

# Shared with the daily sandbox on purpose: bun packages and embedding/tiny model
# weights are static runtime material, and re-downloading them is impossible offline.
export BUN_INSTALL_CACHE_DIR="$HOME/.omp/cache/bun-install"

# The sandbox denies ~/.config/fish (deny_shell_configs), so the shells this agent
# spawns never run brew's shellenv; carry the tool paths through env. Deduped: nono
# warns per PATH entry, and a login PATH already carrying ~/.local/bin doubles one
# grant's warning.
PATH="$(printf '%s' "$HOME/.local/bin:__BREW_PREFIX__/bin:__BREW_PREFIX__/sbin:$PATH" | awk -v RS=: -v ORS=: '!seen[$0]++' | sed 's/:$//')"
export PATH

# ~/.ssh is denied, but git must still sign: ssh-keygen signs through the ssh-agent
# given the PUBLIC key file, host keys from the ~/.config/git copy. Push reaches no
# remote (the allow-list stops it), but signed local commits work.
if [ -r "$HOME/.config/git/sign.pub" ]; then
  GIT_CONFIG_COUNT=$(( ${GIT_CONFIG_COUNT:-0} + 1 ))
  export GIT_CONFIG_COUNT
  export "GIT_CONFIG_KEY_$(( GIT_CONFIG_COUNT - 1 ))"=user.signingkey
  export "GIT_CONFIG_VALUE_$(( GIT_CONFIG_COUNT - 1 ))"="$HOME/.config/git/sign.pub"
fi
if [ -r "$HOME/.config/git/known_hosts" ]; then
  export GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=$HOME/.config/git/known_hosts"
fi

# Supervised mode on purpose, unlike the daily wrapper: domain filtering is a proxy
# feature and the proxy lives in the supervisor, so an allow-listed profile under 'nono
# wrap' is silently unrestricted (found the hard way 2026-11-12: curl 200 from a
# filtered local-omp session). The unsandboxed parent costs the herdr foreground-process
# label (invariant 3), unwanted here anyway. Direct outbound is kernel-blocked while
# filtering is active; the model ports stay open through open_port. --profile is a full
# path, never a name (a registry pack can claim a name; dev-agents header).
exec __BREW_PREFIX__/bin/nono run --allow-cwd \
  --profile /usr/local/etc/nono/local-omp.json \
  -- /usr/local/bin/omp-unsandboxed "$@"
