# Managed by mise.

# The Homebrew prefix's bin on PATH, as a static path rather than
# `brew shellenv`: every Mac this repo runs on has (or gets at bootstrap)
# the prefix, and `brew shellenv` needs Homebrew itself to exist, which a
# fresh machine does not until bootstrap runs. An absent prefix adds nothing.
for p in /opt/homebrew /usr/local
    if test -d $p/bin
        set -gx PATH $p/bin $PATH
        break
    end
end
# mise on nwa is a standalone install in ~/.local/bin. Appended, not
# prepended: on the Macs the Homebrew prefix above sorts ahead of it, so
# brew's mise wins there.
if test -d $HOME/.local/bin
    set -gx PATH $PATH $HOME/.local/bin
end

# mise: activation. mise comes from Homebrew on the Macs and from a
# standalone install in ~/.local/bin on nwa, so it is already on PATH by
# here; the guard keeps the block a no-op where mise is absent.
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

    # starship reads ~/.config/starship.toml by default, which this repo
    # manages, so there is no STARSHIP_CONFIG to set.
    if type -q starship
        starship init fish | source
    end
end
