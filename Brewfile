# The manifest for brew-ecosystem software on the Macs. The brew-bundle task
# concatenates this file with Brewfile.<host> (brew bundle reads a single
# --file; the host file is Brewfile.gza) and runs `brew bundle --no-upgrade`:
# current Homebrew's plain `brew bundle` also upgrades installed entries, so
# the task installs what is missing and `up` (brew upgrade) does the
# upgrading. Why brew and not mise: README, "Why brew + mise".
#
# mise itself is listed so a fresh machine is complete (the bootstrap
# installs Homebrew before it runs).

# omp's tap. trusted: true -- Homebrew 6+ refuses formulae from untrusted
# taps, and the trust state is per-machine (~/.homebrew/trust.json), so
# bundle records it (why: Brewfile.gza). The other taps carry the GUI apps
# below: aerospace (window tiling; its config is in this repo), glance
# (menu-bar dashboard), borders (window borders for aerospace).
tap "can1357/homebrew-tap", trusted: true
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
brew "herdr"
brew "jq"
brew "mas"
brew "mise"
brew "mole"
brew "mosh"
# The sandbox for the coding agents. On the Macs `omp` on PATH is a
# root-owned nono wrapper installed by the dev-agents task (herdr launches
# agents by PATH name, so every launch is sandboxed); the raw binary is
# omp-unsandboxed. The Brewfile carries the tool, the task the policy.
brew "nono"
brew "starship"
# Runs under the dev.mise.syncthing launchd agent (mise.toml), not
# `brew services`.
brew "syncthing"
brew "uv"

# aerospace needs borders (above); the font carries starship's prompt glyphs.
cask "nikitabobko/tap/aerospace"
cask "balenaetcher"
cask "brave-browser"
cask "citrix-workspace"
cask "font-jetbrains-mono-nerd-font"
cask "chamburr/tap/glance"
cask "ghostty"
cask "grandperspective"
# Local dictation (push-to-talk on Option-Space); Parakeet runs on the CPU,
# leaving the GPU for the inference servers.
cask "handy"
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

# mas installs by ID; the name is only a label. The machine must be signed
# in to the App Store before mas can download anything, and the app must
# already be in the account's purchase history -- otherwise the entry
# fails. The explicit `id:` form is required by current homebrew-bundle: a
# positional-ID line ("mas 361285480") aborts the whole bundle with
# "options[:id] should be an Integer".
mas "Keynote", id: 361285480
mas "Numbers", id: 361304891
mas "Obsidian Web Clipper", id: 6720708363
mas "Pages", id: 361309726
mas "Pixelmator Pro", id: 1289583905
mas "uBlock Origin Lite", id: 6745342698
