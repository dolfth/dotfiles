#!/bin/sh
# The offline omp for sensitive work: installed by dev-agents as
# /usr/local/bin/local-omp (root:wheel 755). Same stack as omp-wrapper.sh;
# differences: the generated offline profile, supervised execution (tail
# note), the omp named profile for state, private scratch.
#
# The allow-list holds only the model host (vars.omp_base): web tools, git
# push and package downloads die -- that is the feature. The filter is
# per-host, so on gza every local port is inside the grant.
#
# OMP_PROFILE=local moves omp's whole user base to ~/.omp/profiles/local,
# which the daily profile denies: sensitive facts cannot resurface in a
# networked session's memory, sessions or logs. The name also keeps herdr's
# detection from claiming this as an omp session; HERDR_AGENT labels it.
export HERDR_AGENT=local-omp
export OMP_PROFILE=local

# Scratch and the nono capability manifest stay under the profile tree;
# XDG_CACHE_HOME stays shared -- caches hold runtime material, never docs.
: "${XDG_CACHE_HOME:=$HOME/.cache}"
TMPDIR="$HOME/.omp/profiles/local/tmp"
mkdir -p "$TMPDIR"
export TMPDIR

# Shared with the daily sandbox on purpose: bun packages and embedding/tiny model
# weights are static runtime material, and re-downloading them is impossible offline.
export BUN_INSTALL_CACHE_DIR="$HOME/.omp/cache/bun-install"

# The sandbox denies ~/.config/fish, so spawned shells never run brew's
# shellenv; carry the tool paths through env. Deduped: nono warns per entry.
PATH="$(printf '%s' "$HOME/.local/bin:__BREW_PREFIX__/bin:__BREW_PREFIX__/sbin:$PATH" | awk -v RS=: -v ORS=: '!seen[$0]++' | sed 's/:$//')"
export PATH

# ~/.ssh is denied, but git must still sign: ssh-keygen signs through the
# ssh-agent with the PUBLIC key file (Secure Enclave handle's .pub, loaded
# into the agent by `ssh-add -K -S /usr/lib/ssh-keychain.dylib`); push reaches
# no remote (the allow-list stops it), signed local commits work.
if [ -r "$HOME/.config/git/sign.pub" ]; then
  GIT_CONFIG_COUNT=$(( ${GIT_CONFIG_COUNT:-0} + 1 ))
  export GIT_CONFIG_COUNT
  export "GIT_CONFIG_KEY_$(( GIT_CONFIG_COUNT - 1 ))"=user.signingkey
  export "GIT_CONFIG_VALUE_$(( GIT_CONFIG_COUNT - 1 ))"="$HOME/.config/git/sign.pub"
fi
if [ -r "$HOME/.config/git/known_hosts" ]; then
  export GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=$HOME/.config/git/known_hosts"
fi

# Supervised, unlike the daily wrapper: domain filtering is a proxy feature
# and the proxy lives in the supervisor -- an allow-listed profile under
# 'nono wrap' is silently unrestricted. The lost herdr foreground label
# (invariant 3) is wanted here anyway.
exec __BREW_PREFIX__/bin/nono run --allow-cwd \
  --profile /usr/local/etc/nono/local-omp.json \
  -- /usr/local/bin/omp-unsandboxed "$@"
