#!/bin/sh
# The sandboxed omp: this file is installed as /usr/local/bin/omp, root:wheel
# 755, by `mise run dev-agents` (__BREW_PREFIX__ is substituted at install).
# The raw binary is /usr/local/bin/omp-unsandboxed. The name on PATH is the
# wrapper, so anything that launches omp by name -- including `herdr agent
# start` -- gets the sandbox.
#
# `nono wrap`, never `nono run`: wrap execs into the binary, so omp is the
# pane's foreground process and herdr can read HERDR_AGENT off it. With `run`
# a non-dumpable supervisor sits in front and every pane shows "unknown".
export HERDR_AGENT=omp

# nono writes its capability manifest to $TMPDIR (read it back with
# `nono why --self`), and ~/.cache is the writable temp home the profile
# grants readable too.
: "${XDG_CACHE_HOME:=$HOME/.cache}"
TMPDIR="$XDG_CACHE_HOME/nono-tmp/omp"
mkdir -p "$TMPDIR"
export TMPDIR

# mnemopi-embed prepares its fastembed runtime with `bun install` (omp
# re-execs as bun via BUN_BE_BUN, env inherited); the default cache ~/.bun
# is denied, so point it into the granted ~/.omp instead.
export BUN_INSTALL_CACHE_DIR="$HOME/.omp/cache/bun-install"

# The sandbox denies ~/.config/fish (deny_shell_configs), so the shells this
# agent spawns never run brew's shellenv. Carry the tool paths through env.
# Deduped: nono warns per PATH entry, and a login PATH already carrying
# ~/.local/bin turns one intentional rw grant into two warnings.
PATH="$(printf '%s' "$HOME/.local/bin:__BREW_PREFIX__/bin:__BREW_PREFIX__/sbin:$PATH" | awk -v RS=: -v ORS=: '!seen[$0]++' | sed 's/:$//')"
export PATH

# ~/.ssh is denied, but git must still sign and push: ssh-keygen signs through
# the ssh-agent given the PUBLIC key file, and ssh verifies hosts from a known
# hosts copy under ~/.config/git (both seeded by dev-agents). If these fail
# with "no agent" or "host key verification failed", the ssh-agent simply has
# no key loaded (ssh-add --apple-use-keychain ~/.ssh/id_ed25519, once per
# boot, from an unsandboxed shell).
if [ -r "$HOME/.config/git/sign.pub" ]; then
  GIT_CONFIG_COUNT=$(( ${GIT_CONFIG_COUNT:-0} + 1 ))
  export GIT_CONFIG_COUNT
  export "GIT_CONFIG_KEY_$(( GIT_CONFIG_COUNT - 1 ))"=user.signingkey
  export "GIT_CONFIG_VALUE_$(( GIT_CONFIG_COUNT - 1 ))"="$HOME/.config/git/sign.pub"
fi
if [ -r "$HOME/.config/git/known_hosts" ]; then
  export GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=$HOME/.config/git/known_hosts"
fi

# --profile is a full path, never a name: names resolve at run time against
# the user-editable ~/.config/nono/profiles, and a `nono pull`ed registry pack
# can claim one (nwa saw exactly that replace a profile with one granting
# ~/.claude and the network).
exec __BREW_PREFIX__/bin/nono wrap --allow-cwd \
  --profile /usr/local/etc/nono/omp.json \
  -- /usr/local/bin/omp-unsandboxed "$@"
