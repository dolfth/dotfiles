# The manifest for brew-ecosystem software on the Macs. The brew-bundle task
# concatenates this file with Brewfile.<host> (brew bundle reads one --file; the host
# file is Brewfile.gza) and runs `brew bundle --no-upgrade`: plain `brew bundle` on
# current Homebrew also upgrades installed entries, so this installs what is missing
# and `up` (brew upgrade) does the upgrading. Why brew and not mise: README, "Why brew
# + mise". mise itself is listed so a fresh machine is complete (bootstrap installs
# Homebrew before it runs).

# omp's tap. trusted: true, because Homebrew 6+ refuses formulae from untrusted taps
# and trust is per-machine state (~/.homebrew/trust.json), so bundle records it (why in
# full: Brewfile.gza). The other taps carry the apps below: aerospace (window tiling;
# config in this repo), glance (menu-bar dashboard), borders, the tsk task board CLI.
tap "can1357/homebrew-tap", trusted: true
tap "chamburr/tap", trusted: true
tap "nikitabobko/tap", trusted: true
tap "FelixKratz/formulae", trusted: true
tap "smarzban/tap", trusted: true

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
# The sandbox for the coding agents. On the Macs `omp` on PATH is a root-owned nono
# wrapper the dev-agents task installs (herdr launches agents by PATH name, so every
# launch is sandboxed); the raw binary stays omp-unsandboxed. Brewfile carries the tool,
# the task the policy.
brew "nono"
# Lints the repo's own task scripts; the mise-tasks/check task runs it.
brew "shellcheck"
brew "starship"
# Runs under the dev.mise.syncthing launchd agent (mise.toml), not
# `brew services`.
brew "syncthing"
# Terminal task board. The herdr-plugins task registers its herdr plugin;
# the keybindings are in herdr/config.toml.
brew "smarzban/tap/tsk"
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
# Objective-See's application firewall. First run needs a terminal: the cask
# installs a system extension that must be approved in Privacy & Security.
cask "lulu"
cask "monitorcontrol"
cask "notunes"
cask "obsidian"
cask "soulseek"
cask "tailscale-app"
cask "the-unarchiver"
cask "utm"
cask "vscodium"
cask "whatcable"

# mas installs by ID; the name is a label. The machine must be signed in to the App
# Store and the app must be in that account's purchase history, or the entry fails. The
# explicit `id:` form is what current homebrew-bundle accepts: a positional-ID line
# ("mas 361285480") aborts the whole bundle.
mas "Keynote", id: 361285480
mas "Numbers", id: 361304891
mas "Obsidian Web Clipper", id: 6720708363
mas "Pages", id: 361309726
mas "Pixelmator Pro", id: 1289583905
mas "uBlock Origin Lite", id: 6745342698
