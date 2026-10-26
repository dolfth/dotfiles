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
# mise itself is in the manifest so a fresh machine is complete (the
# bootstrap installs Homebrew before it runs).

# can1357/homebrew-tap: the tap for omp (the coding agent). trusted: true --
# Homebrew 6+ refuses formulae from untrusted taps, and the trust state is
# per-machine (~/.homebrew/trust.json); bundle records it (why: Brewfile.gza).
tap "can1357/homebrew-tap", trusted: true

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
# omp: the coding agent (its config deploys per host via the mise module;
# the models run on gza, reached over Tailscale).
brew "omp"
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
