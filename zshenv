# Managed by mise. macOS only.
#
# ~/.zshenv is the only zsh startup file a `$SHELL -c '<posix>'` child reads
# (no /etc/zshenv; path_helper is login-only; zshrc is interactive-only).
# mosh's server handshake is such a child: without this file its ssh cannot
# find mosh-server. Keep it to PATH, the editor and the key provider.

# The Secure Enclave as ssh's security-key provider: without it ssh and
# ssh-keygen answer "No FIDO SecurityKeyProvider specified" the moment a key
# is an sk key (~/.ssh/id_ecdsa_sk). Fish sets the same var in config.fish;
# the launchd jobs that ssh (nwa-health) carry it in their plist.
export SSH_SK_PROVIDER=/usr/lib/ssh-keychain.dylib

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
