# shellcheck shell=bash
# Shared shell plumbing for the mise tasks and the bootstrap hooks.

# A non-login ssh session (`mise bootstrap remote`) carries only system dirs
# on PATH: find mise (brew, Nix, standalone) before `mise run`. Sourcing also
# puts brew on PATH for the package phase's own calls.
resolve_mise() {
  if ! command -v mise >/dev/null 2>&1; then
    for d in /opt/homebrew/bin /run/current-system/sw/bin "$HOME"/.local/share/mise/bin "$HOME"/.local/bin "$HOME"/.cargo/bin /usr/local/bin; do
      [ -x "$d/mise" ] && PATH="$d:$PATH" && break
    done
  fi
}

# The host identity as the config declares it: the host module's [env]
# exports HOST, so empty means the module did not load -- an explicit
# unknown. The OS's $HOSTNAME is never consulted: the question is which
# machine the config selected, not what the OS calls itself.
host_id() { printf '%s' "${HOST:-}"; }
