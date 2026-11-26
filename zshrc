# Managed by mise. macOS only.
#
# zsh is macOS's login shell and stays that way: plenty of software runs
# `$SHELL -c '<posix syntax>'`, and fish is not POSIX. Hand off to fish for
# interactive use only, as the fish docs recommend. PATH and $EDITOR live in
# zshenv, the one file `zsh -c` reads.

# Three guards, all load-bearing:
#   parent != fish           -- `zsh` typed in fish must stay zsh; ps prints
#                               comm as a path, so compare the basename (:t)
#                               against *fish
#   no ZSH_EXECUTION_STRING  -- set by `zsh -c`; hijacking it breaks every
#                               tool that shells out with POSIX syntax
#   login flag propagated    -- so fish sources its login config too
if [[ -n "$(command -v fish)" \
   && "${$(/bin/ps -o comm= -p $PPID):t}" != *fish \
   && -z "$ZSH_EXECUTION_STRING" ]]; then
  if [[ -o login ]]; then
    exec fish --login
  else
    exec fish
  fi
fi
