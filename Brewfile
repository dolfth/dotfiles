# The single source of truth for brew-ecosystem software on the Macs.
#
# Run by the bootstrap's brew-bundle task, which concatenates this file and
# Brewfile.<host> into one manifest -- the host file is Brewfile.gza (the
# desktop's local-LLM servers; the only per-host brew entries) -- because
# brew bundle reads a single --file. --no-upgrade: current Homebrew's plain
# `brew bundle` also upgrades installed entries; the task installs what is
# missing, and daily upgrades go through `up` (brew upgrade).
#
# Why brew and not mise: README, "Why brew + mise".
#
# mise itself is in the manifest so a fresh machine is complete (the
# bootstrap installs Homebrew before it runs).

# can1357/homebrew-tap: the tap for omp (the coding agent). trusted: true --
# Homebrew 6+ refuses formulae from untrusted taps, and the trust state is
# per-machine (~/.homebrew/trust.json); bundle records it (why: Brewfile.gza).
tap "can1357/homebrew-tap", trusted: true
# Taps for the GUI apps below: aerospace (window tiling; its config is in
# this repo), glance (menu-bar dashboard), and borders (window borders for
# aerospace).
tap "chamburr/tap", trusted: true
tap "nikitabobko/tap", trusted: true
tap "FelixKratz/formulae", trusted: true

brew "bat"
brew "dust"
brew "exiftool"
brew "ffmpeg"
brew "FelixKratz/formulae/borders"
brew "fish"
brew "helix"
brew "git"
brew "jq"
brew "mas"
brew "mise"
brew "mole"
brew "mosh"
# omp: the coding agent (its config deploys to every host via the shared
# mise dotfiles; the models run on gza, reached over Tailscale).
brew "omp"
brew "starship"
# Background sync (both Macs; its launchd agent lives in mise.toml, so it
# runs under mise, not `brew services`).
brew "syncthing"
brew "uv"

# Both Macs use the patched font (starship's prompt glyphs) and the terminal;
# the desktop has its own display but is also reached over mosh/Tailscale.
cask "nikitabobko/tap/aerospace"
cask "balenaetcher"
cask "brave-browser"
cask "citrix-workspace"
cask "font-jetbrains-mono-nerd-font"
cask "chamburr/tap/glance"
cask "ghostty"
cask "grandperspective"
cask "iina"
cask "imageoptim"
cask "linearmouse"
cask "monitorcontrol"
cask "notunes"
cask "obsidian"
cask "soulseek"
cask "tailscale-app"
cask "the-unarchiver"
cask "utm"
cask "vscodium"
cask "whatcable"

# App Store -- mas installs by ID; the name is only a label. The explicit
# `id:` form is required by current homebrew-bundle: a positional-ID line
# ("mas 1435127111") aborts the whole bundle with "options[:id] should be
# an Integer". The app must already be in your purchase history.
mas "KeePassium", id: 1435127111
mas "Keynote", id: 361285480
mas "Numbers", id: 361304891
mas "Obsidian Web Clipper", id: 6720708363
mas "Pages", id: 361309726
mas "Pixelmator Pro", id: 1289583905
mas "uBlock Origin Lite", id: 6745342698
