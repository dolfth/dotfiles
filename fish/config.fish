# Managed by mise.

# The Homebrew prefix's bin on PATH as a static path, not `brew shellenv`: shellenv
# needs Homebrew to exist, and a fresh machine has none until bootstrap. An absent
# prefix adds nothing.
for p in /opt/homebrew /usr/local
    if test -d $p/bin
        set -gx PATH $p/bin $PATH
        break
    end
end
# ~/.local/bin on PATH. Appended, not prepended: the Homebrew prefix
# above sorts ahead of it, so brew's mise wins.
if test -d $HOME/.local/bin
    set -gx PATH $PATH $HOME/.local/bin
end

# mise: activation. It is on PATH by here (the brew prefix or
# ~/.local/bin); the guard keeps the block a no-op where mise is absent.
if type -q mise
    if status is-interactive
        mise activate fish | source
    else
        mise activate fish --shims | source
    end
end

if status is-interactive
    alias ll "ls -alh"

    # `..` as an abbreviation rather than a function: fish's parser rejects
    # `..` as a function name, but an abbreviation expands `..` to `cd ..`.
    abbr .. "cd .."

    if type -q starship
        starship init fish | source
    end
end
