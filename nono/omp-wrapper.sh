#!/bin/sh
# The sandboxed omp, installed as /usr/local/bin/omp (root:wheel 755) by `mise run
# dev-agents`; __BREW_PREFIX__ is substituted at install. The raw binary is
# /usr/local/bin/omp-unsandboxed. The name on PATH is the wrapper, so anything that
# launches omp by name -- `herdr agent start` included -- gets the sandbox.
#
# `nono wrap`, never `nono run`: wrap execs into the binary, so omp is the pane's
# foreground process and herdr can read HERDR_AGENT off it; `run` puts a non-dumpable
# supervisor in front and every pane shows "unknown".
export HERDR_AGENT=omp

# nono writes its capability manifest to $TMPDIR (read it back with `nono why
# --self`); ~/.cache is the writable temp home the profile grants readable too.
: "${XDG_CACHE_HOME:=$HOME/.cache}"
TMPDIR="$XDG_CACHE_HOME/nono-tmp/omp"
mkdir -p "$TMPDIR"
export TMPDIR

# mnemopi-embed prepares its fastembed runtime with `bun install` (omp re-execs as bun
# via BUN_BE_BUN, env inherited); the default cache ~/.bun is denied, so it goes under
# the granted ~/.omp instead.
export BUN_INSTALL_CACHE_DIR="$HOME/.omp/cache/bun-install"

# The sandbox denies ~/.config/fish (deny_shell_configs), so the shells this agent
# spawns never run brew's shellenv; carry the tool paths through env. Deduped: nono
# warns per PATH entry, and a login PATH already carrying ~/.local/bin turns one grant
# into two warnings.
PATH="$(printf '%s' "$HOME/.local/bin:__BREW_PREFIX__/bin:__BREW_PREFIX__/sbin:$PATH" | awk -v RS=: -v ORS=: '!seen[$0]++' | sed 's/:$//')"
export PATH

# ~/.ssh is denied and so is /usr/bin/ssh (dev-agents #11): no ssh transport from
# this sandbox -- push reaches a remote over https only. git must still sign
# locally: ssh-keygen (not denied) signs through the ssh-agent given the PUBLIC key
# file seeded by dev-agents. "no agent" means the agent simply has no key loaded --
# one ssh-add, unsandboxed, per boot.
if [ -r "$HOME/.config/git/sign.pub" ]; then
  GIT_CONFIG_COUNT=$(( ${GIT_CONFIG_COUNT:-0} + 1 ))
  export GIT_CONFIG_COUNT
  export "GIT_CONFIG_KEY_$(( GIT_CONFIG_COUNT - 1 ))"=user.signingkey
  export "GIT_CONFIG_VALUE_$(( GIT_CONFIG_COUNT - 1 ))"="$HOME/.config/git/sign.pub"
fi

# --profile is a full path, never a name: names resolve at run time against the
# user-editable ~/.config/nono/profiles, and a `nono pull`ed registry pack can claim one
# (nwa saw exactly that replace a profile with one granting ~/.claude and the network).
exec __BREW_PREFIX__/bin/nono wrap --allow-cwd \
  --profile /usr/local/etc/nono/omp.json \
  -- /usr/local/bin/omp-unsandboxed "$@"
