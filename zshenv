# Managed by mise. macOS only (mac module).
#
# ~/.zshenv is the only zsh startup file a `$SHELL -c '<posix>'` child reads:
# no /etc/zshenv exists, /etc/zprofile's path_helper runs only for login
# shells, and ~/.zshrc only interactive ones. mosh's server handshake is such
# a child -- without this file its ssh finds only /usr/bin:/bin:/usr/sbin:/sbin
# and reports mosh-server missing. Keep it to PATH and the editor; the shell
# behavior lives in zshrc.

# helix as $EDITOR/$VISUAL here rather than in zshrc: `zsh -c` skips zshrc.
export EDITOR=hx
export VISUAL=hx

# The Homebrew prefix's bin on PATH, as a static path rather than
# `brew shellenv` (see config.fish): a fresh machine has no Homebrew yet.
for p in /opt/homebrew /usr/local; do
  if [ -d "$p/bin" ]; then
    PATH="$p/bin:$PATH"
    break
  fi
done
