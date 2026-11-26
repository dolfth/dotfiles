# Managed by mise. macOS only.
#
# ~/.zshenv is the only zsh startup file a `$SHELL -c '<posix>'` child reads
# (no /etc/zshenv; path_helper is login-only; zshrc is interactive-only).
# mosh's server handshake is such a child: without this file its ssh cannot
# find mosh-server. Keep it to PATH and the editor.

# helix as $EDITOR/$VISUAL here rather than in zshrc: `zsh -c` skips zshrc.
export EDITOR=hx
export VISUAL=hx

# The brew prefix on PATH as a static path, not `brew shellenv`: a fresh
# machine has no Homebrew yet.
for p in /opt/homebrew /usr/local; do
  if [ -d "$p/bin" ]; then
    PATH="$p/bin:$PATH"
    break
  fi
done
