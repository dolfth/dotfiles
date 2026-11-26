#!/bin/sh
# The sandboxed omp, installed by dev-agents as /usr/local/bin/omp (root:wheel
# 755); __BREW_PREFIX__ is substituted at install; the raw binary is
# omp-unsandboxed. The name on PATH is the wrapper, so launches by name --
# herdr included -- get the sandbox.
#
# `nono wrap`, never `nono run`: wrap execs into the binary, so omp stays the
# pane's foreground process and herdr can read HERDR_AGENT off it; run's
# supervisor makes every pane show "unknown".
export HERDR_AGENT=omp

# The writable temp home the profile grants; nono writes its capability
# manifest to $TMPDIR.
: "${XDG_CACHE_HOME:=$HOME/.cache}"
TMPDIR="$XDG_CACHE_HOME/nono-tmp/omp"
mkdir -p "$TMPDIR"
export TMPDIR

# mnemopi-embed prepares its runtime with `bun install` (omp re-execs as bun,
# env inherited); the default cache ~/.bun is denied, so it goes under ~/.omp.
export BUN_INSTALL_CACHE_DIR="$HOME/.omp/cache/bun-install"

# The sandbox denies ~/.config/fish, so spawned shells never run brew's
# shellenv; carry the tool paths through env. Deduped: nono warns per entry.
PATH="$(printf '%s' "$HOME/.local/bin:__BREW_PREFIX__/bin:__BREW_PREFIX__/sbin:$PATH" | awk -v RS=: -v ORS=: '!seen[$0]++' | sed 's/:$//')"
export PATH

# ssh is dead in this sandbox (dev-agents invariant 11): push goes over https
# only. git must still sign locally: ssh-keygen (not denied) signs through the
# ssh-agent with the PUBLIC key file dev-agents seeds -- the Secure Enclave
# handle's .pub, the private half never leaves the chip. "no agent" means no
# key loaded: one unsandboxed `ssh-add -K -S /usr/lib/ssh-keychain.dylib` per
# boot.
if [ -r "$HOME/.config/git/sign.pub" ]; then
  GIT_CONFIG_COUNT=$(( ${GIT_CONFIG_COUNT:-0} + 1 ))
  export GIT_CONFIG_COUNT
  export "GIT_CONFIG_KEY_$(( GIT_CONFIG_COUNT - 1 ))"=user.signingkey
  export "GIT_CONFIG_VALUE_$(( GIT_CONFIG_COUNT - 1 ))"="$HOME/.config/git/sign.pub"
fi

# --profile is a full path, never a name: names resolve at run time against the
# user-editable ~/.config/nono/profiles, and a `nono pull`ed registry pack can claim one.
exec __BREW_PREFIX__/bin/nono wrap --allow-cwd \
  --profile /usr/local/etc/nono/omp.json \
  -- /usr/local/bin/omp-unsandboxed "$@"
