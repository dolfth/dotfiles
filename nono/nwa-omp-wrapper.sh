#!/bin/sh
# The nwa-maintenance omp: installed as /usr/local/bin/nwa-omp (root:wheel 755)
# by `mise run dev-agents` (__BREW_PREFIX__ substituted at install). The one omp
# entry point where ssh lives; the daily omp denies /usr/bin/ssh. Its only job is
# maintaining nwa (nixos-config edits, the E1 deploy over Tailscale SSH), so start
# it from the nixos-config checkout: --allow-cwd makes that tree the agent's whole
# document world, like local-omp's.
#
# Wrapped, not supervised: the network allow-list cannot carry ssh on macOS -- the
# proxy tunnels HTTP(S) only (nolabs-ai/nono#756) and Seatbelt cannot filter
# outbound by port -- so this profile sets no network policy at all and says so
# (dev-agents #12). An allow-list here would be decoration. Outbound is what the
# daily omp has always had; the isolation this profile owns is filesystem and
# state: the named profile tree, no shared tsk store, and the launched workdir.
#
# State: OMP_PROFILE=nwa moves omp's user base to ~/.omp/profiles/nwa, invisible
# to the daily sandbox (it denies $HOME/.omp/profiles) and to local-omp (it
# denies .tsk; the trees never meet). herdr labels the pane nwa-omp.
export HERDR_AGENT=nwa-omp
export OMP_PROFILE=nwa

# Scratch and the nono capability manifest stay under the profile tree.
# XDG_CACHE_HOME stays shared: caches hold runtime material, never doc content.
: "${XDG_CACHE_HOME:=$HOME/.cache}"
TMPDIR="$HOME/.omp/profiles/nwa/tmp"
mkdir -p "$TMPDIR"
export TMPDIR

# Shared with the other sandboxes on purpose: bun packages and embedding weights
# are static runtime material.
export BUN_INSTALL_CACHE_DIR="$HOME/.omp/cache/bun-install"

# The sandbox denies ~/.config/fish (deny_shell_configs), so the shells this
# agent spawns never run brew's shellenv; carry the tool paths through env.
# Deduped: nono warns per PATH entry.
PATH="$(printf '%s' "$HOME/.local/bin:__BREW_PREFIX__/bin:__BREW_PREFIX__/sbin:$PATH" | awk -v RS=: -v ORS=: '!seen[$0]++' | sed 's/:$//')"
export PATH

# ~/.ssh is denied even here: auth goes through ssh-agent (public key file for
# signing, tailnet identity for nwa), never key files. git signs from the
# ~/.config/git copy; host keys land in the profile tree's known_hosts instead
# of the denied ~/.ssh -- tailscale host keys rotate with the node key, so this
# tree keeps its own, seeded at install with the git copy.
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
