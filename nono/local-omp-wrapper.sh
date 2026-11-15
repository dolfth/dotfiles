#!/bin/sh
# The offline omp for sensitive work: installed as /usr/local/bin/local-omp,
# root:wheel 755, by `mise run dev-agents` (__BREW_PREFIX__ substituted at
# install). Same stack as omp-wrapper.sh with four differences: the
# generated offline profile, supervised execution (see the tail note), the
# omp named profile for state, and private scratch.
#
# Offline: the profile's network allow-list holds only the model servers
# (vars.omp_base -- 127.0.0.1 on gza, the tailnet FQDN elsewhere -- on the
# GPU-pool ports). Web tools, git push, package downloads die. That is the
# feature.
#
# State: OMP_PROFILE=local relocates omp's whole user base to
# ~/.omp/profiles/local, which the daily profile denies. Sensitive facts
# cannot resurface in a networked session's memory, sessions, or logs.
# Scratch lives inside that tree too, so it is invisible to daily sessions.
#
# The name is deliberate: herdr's agent detection does not claim local-omp
# as an omp session; the pane is labeled by HERDR_AGENT only.
export HERDR_AGENT=local-omp
export OMP_PROFILE=local

# Scratch and the nono capability manifest stay under the profile tree.
# XDG_CACHE_HOME stays shared: caches there hold runtime material (models,
# packages), never doc content -- but keep docs in $TMPDIR anyway.
: "${XDG_CACHE_HOME:=$HOME/.cache}"
TMPDIR="$HOME/.omp/profiles/local/tmp"
mkdir -p "$TMPDIR"
export TMPDIR

# Shared with the daily sandbox on purpose: bun packages and embedding/tiny
# model weights are static runtime material; re-downloading them is
# impossible offline (network is the point).
export BUN_INSTALL_CACHE_DIR="$HOME/.omp/cache/bun-install"

# The sandbox denies ~/.config/fish (deny_shell_configs), so the shells this
# agent spawns never run brew's shellenv. Carry the tool paths through env.
# Deduped: nono warns per PATH entry, and a login PATH already carrying
# ~/.local/bin turns one intentional rw grant into two warnings.
PATH="$(printf '%s' "$HOME/.local/bin:__BREW_PREFIX__/bin:__BREW_PREFIX__/sbin:$PATH" | awk -v RS=: -v ORS=: '!seen[$0]++' | sed 's/:$//')"
export PATH

# ~/.ssh is denied, but git must still sign: ssh-keygen signs through the
# ssh-agent given the PUBLIC key file, host keys from the copy under
# ~/.config/git. Push reaches no remote here -- the network allow-list stops
# it -- but signed local commits (e.g. a private notes repo) work.
if [ -r "$HOME/.config/git/sign.pub" ]; then
  GIT_CONFIG_COUNT=$(( ${GIT_CONFIG_COUNT:-0} + 1 ))
  export GIT_CONFIG_COUNT
  export "GIT_CONFIG_KEY_$(( GIT_CONFIG_COUNT - 1 ))"=user.signingkey
  export "GIT_CONFIG_VALUE_$(( GIT_CONFIG_COUNT - 1 ))"="$HOME/.config/git/sign.pub"
fi
if [ -r "$HOME/.config/git/known_hosts" ]; then
  export GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=$HOME/.config/git/known_hosts"
fi

# Supervised mode on purpose, unlike the daily wrapper: domain filtering is
# a proxy feature and the proxy lives in the supervisor -- 'nono wrap'
# carries no proxy, so an allow-listed profile under wrap is silently
# unrestricted (docs/cli/features/execution-modes; found the hard way
# 2026-11-12: curl 200 from a filtered local-omp session). The unsandboxed
# parent costs the herdr foreground-process label (invariant 3), which
# local-omp does not want anyway. Direct outbound is kernel-blocked while
# filtering is active; the model ports above stay open via open_port.
# --profile stays a full path, never a name (a registry pack can claim a
# name; see dev-agents header).
exec __BREW_PREFIX__/bin/nono run --allow-cwd \
  --profile /usr/local/etc/nono/local-omp.json \
  -- /usr/local/bin/omp-unsandboxed "$@"
