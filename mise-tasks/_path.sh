# shellcheck shell=bash
# Shared shell plumbing for the mise tasks and the bootstrap hooks.

# A non-login ssh session (`mise bootstrap remote`) has only bare system dirs
# on PATH: find mise (brew prefix, Nix store, standalone installs) before
# `mise run` needs it. Sourcing this file puts brew on PATH for the
# package phase's own calls too.
resolve_mise() {
  if ! command -v mise >/dev/null 2>&1; then
    for d in /opt/homebrew/bin /run/current-system/sw/bin "$HOME"/.local/share/mise/bin "$HOME"/.local/bin "$HOME"/.cargo/bin /usr/local/bin; do
      [ -x "$d/mise" ] && PATH="$d:$PATH" && break
    done
  fi
}

# The host identity as the config declares it: HOST is exported by the
# selected host module's [env], so an empty answer means the module did not
# load (wrong cwd, missing selection, a bare shell) -- an explicit unknown.
# The OS's own $HOSTNAME is deliberately never consulted: the gate asks
# "which machine did this checkout's config select", not "what does the OS
# call itself".
host_id() { printf '%s' "${HOST:-}"; }
