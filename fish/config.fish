# Managed by mise.

# Homebrew's bin is not on PATH by default. Harmless no-op off macOS.
for p in /opt/homebrew /usr/local
    if test -x $p/bin/brew
        $p/bin/brew shellenv fish | source
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
