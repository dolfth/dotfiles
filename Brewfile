# The single source of truth for brew-ecosystem software on the Macs.
#
# Run by the bootstrap's brew-bundle task:
#   brew bundle --file=Brewfile --file=Brewfile.<host>
# where the host file is Brewfile.mca (the laptop's GUI apps) or
# Brewfile.gza (the desktop's local-LLM servers). brew bundle installs what
# is missing and does not upgrade what is present; daily upgrades go
# through `up` (brew upgrade).
#
# Why brew and not mise: README, "Why brew + mise".
#
# Shared by both Macs. mise itself is included so the manifest is complete
# for a fresh machine (the bootstrap installs Homebrew before it runs).

brew "bat"
brew "duckdb"
brew "dust"
brew "exiftool"
brew "ffmpeg"
brew "fish"
brew "git"
brew "git-delta"
brew "htop"
brew "jq"
brew "mas"
brew "mise"
brew "mole"
brew "mosh"
brew "neovim"
brew "python@3.14"
brew "starship"
brew "uv"

# Both Macs use the patched font (starship's prompt glyphs) and the terminal;
# the desktop runs headless but is still reached over mosh/Tailscale.
cask "font-jetbrains-mono-nerd-font"
cask "ghostty"
cask "tailscale-app"
