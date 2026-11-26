#!/bin/sh
# The nwa-maintenance omp: installed by dev-agents as /usr/local/bin/nwa-omp
# (root:wheel 755). The one omp entry point where ssh lives; its only job is
# maintaining nwa, so start it from the nixos-config checkout -- --allow-cwd
# makes that tree the agent's whole document world.
#
# Wrapped, not supervised: an allow-list cannot carry ssh (the proxy tunnels
# HTTP(S) only, nono#756; Seatbelt cannot filter by port), so this profile
# sets no network policy at all (dev-agents invariant 12). The isolation it
# owns is filesystem and state: named profile tree, no shared tsk store, the
# launched workdir.
#
# OMP_PROFILE=nwa moves omp's user base to ~/.omp/profiles/nwa, invisible to
# the daily sandbox and to local-omp alike.
export HERDR_AGENT=nwa-omp
export OMP_PROFILE=nwa

# Scratch and the capability manifest under the profile tree;
# XDG_CACHE_HOME stays shared -- runtime material only.
: "${XDG_CACHE_HOME:=$HOME/.cache}"
TMPDIR="$HOME/.omp/profiles/nwa/tmp"
mkdir -p "$TMPDIR"
export TMPDIR

# Shared with the other sandboxes on purpose: bun packages and embedding weights
# are static runtime material.
export BUN_INSTALL_CACHE_DIR="$HOME/.omp/cache/bun-install"

# The sandbox denies ~/.config/fish, so spawned shells never run brew's
# shellenv; carry the tool paths through env. Deduped: nono warns per entry.
PATH="$(printf '%s' "$HOME/.local/bin:__BREW_PREFIX__/bin:__BREW_PREFIX__/sbin:$PATH" | awk -v RS=: -v ORS=: '!seen[$0]++' | sed 's/:$//')"
export PATH

# ~/.ssh is denied even here: signing goes through the ssh-agent with the
# PUBLIC key, nwa auth is the tailnet identity, never a key file. Host keys
# land in the profile tree's known_hosts -- tailscale keys rotate with the
# node key, so this tree keeps its own, seeded at install.
if [ -r "$HOME/.config/git/sign.pub" ]; then
  GIT_CONFIG_COUNT=$(( ${GIT_CONFIG_COUNT:-0} + 1 ))
  export GIT_CONFIG_COUNT
  export "GIT_CONFIG_KEY_$(( GIT_CONFIG_COUNT - 1 ))"=user.signingkey
  export "GIT_CONFIG_VALUE_$(( GIT_CONFIG_COUNT - 1 ))"="$HOME/.config/git/sign.pub"
fi
export GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=$HOME/.omp/profiles/nwa/known_hosts -o StrictHostKeyChecking=accept-new"

# --profile is a full path, never a name (a registry pack can claim a name).
exec __BREW_PREFIX__/bin/nono wrap --allow-cwd \
  --profile /usr/local/etc/nono/nwa-omp.json \
  -- /usr/local/bin/omp-unsandboxed "$@"
