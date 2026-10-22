# The single source of truth for brew-ecosystem software on the Macs.
#
# Run by the bootstrap's brew-bundle task, which concatenates this file and
# Brewfile.<host> into one manifest -- the host file is Brewfile.mca (the
# laptop's GUI apps) or Brewfile.gza (the desktop's local-LLM servers) --
# because brew bundle reads a single --file. --no-upgrade: current
# Homebrew's plain `brew bundle` also upgrades installed entries; the task
# installs what is missing, and daily upgrades go through `up` (brew
# upgrade).
#
# Why brew and not mise: README, "Why brew + mise".
#
# Shared by both Macs. mise itself is included so the manifest is complete
# for a fresh machine (the bootstrap installs Homebrew before it runs).

brew "bat"
brew "dust"
brew "exiftool"
brew "ffmpeg"
brew "fish"
brew "helix"
brew "git"
brew "jq"
brew "mas"
brew "mise"
brew "mole"
brew "mosh"
brew "starship"
brew "uv"

# Both Macs use the patched font (starship's prompt glyphs) and the terminal;
# the desktop runs headless but is still reached over mosh/Tailscale.
cask "font-jetbrains-mono-nerd-font"
cask "ghostty"
# LinearMouse: pointer tuning and back/forward buttons (its config is seeded
# from mise.mac.toml; first launch asks for Accessibility).
cask "linearmouse"
cask "tailscale-app"
