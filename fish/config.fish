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

# nvim as $EDITOR/$VISUAL.
set -gx EDITOR nvim
set -gx VISUAL nvim

# mise: activation. mise comes from Homebrew (brew install mise, via the
# bootstrap) on the Macs and from Nix on nwa, so it is already on PATH; the
# guard keeps the block a no-op where mise is absent.
if type -q mise
    if status is-interactive
        mise activate fish | source
    else
        mise activate fish --shims | source
    end
end

if status is-interactive
    alias ll "ls -alh"

    # starship reads ~/.config/starship.toml by default, which this repo
    # manages, so there is no STARSHIP_CONFIG to set.
    if type -q starship
        starship init fish | source
    end
end
