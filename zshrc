# Managed by mise. macOS only (mac module).
#
# zsh is macOS's login shell and stays that way on purpose: plenty of software
# runs `$SHELL -c '<posix syntax>'`, and fish is not POSIX. So keep a POSIX
# login shell and hand off to fish for interactive use only -- which is what
# the fish docs themselves recommend:
#   https://fishshell.com/docs/current/index.html#default-shell

# nvim as $EDITOR/$VISUAL here too, not just in fish: `zsh -c` skips the
# hand-off below entirely.
export EDITOR=nvim
export VISUAL=nvim

# The Homebrew prefix's bin on PATH, as a static path rather than
# `brew shellenv` (see config.fish): a fresh machine has no Homebrew yet.
for p in /opt/homebrew /usr/local; do
  if [ -d "$p/bin" ]; then
    PATH="$p/bin:$PATH"
    break
  fi
done

# Three guards, all load-bearing:
#   parent != fish        -- `zsh` typed in fish must stay zsh. macOS ps prints
#                            comm as a path (/opt/homebrew/bin/fish) or -fish,
#                            so compare the basename (:t) against *fish
#   no ZSH_EXECUTION_STRING -- set by `zsh -c "..."`; hijacking that would break
#                              every tool that shells out with POSIX syntax
#   login flag propagated -- so fish sources its login config too
if [[ -n "$(command -v fish)" \
   && "${$(/bin/ps -o comm= -p $PPID):t}" != *fish \
   && -z "$ZSH_EXECUTION_STRING" ]]; then
  if [[ -o login ]]; then
    exec fish --login
  else
    exec fish
  fi
fi
