# Managed by chezmoi.

# Homebrew's bin is not on PATH by default. Harmless no-op off macOS.
for p in /opt/homebrew /usr/local
    if test -x $p/bin/brew
        $p/bin/brew shellenv fish | source
        break
    end
end

# What `programs.neovim.defaultEditor = true` used to do in the NixOS module.
set -gx EDITOR nvim
set -gx VISUAL nvim

if status is-interactive
    alias ll "ls -alh"

    # starship reads ~/.config/starship.toml by default, which chezmoi manages,
    # so there is no STARSHIP_CONFIG to set.
    if type -q starship
        starship init fish | source
    end
end
