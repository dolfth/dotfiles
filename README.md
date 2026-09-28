# dotfiles

chezmoi source for three machines:

| Host | OS | Role |
|---|---|---|
| `mca` | macOS | laptop |
| `gza` | macOS | desktop, always-on omlx server |
| `nwa` | NixOS | server |

Per-host data lives in `.chezmoidata.yaml`: the prompt accent and icon, and
for Macs a `kind` (`laptop` | `desktop`) that selects the power profile, the
Brewfile and the omlx server setup. Unknown hosts get the fallback accent and
the laptop profile, so add a new Mac there before its first apply. Templates
look up the current host through `.chezmoitemplates/host` and `kind`.

## Bootstrap a Mac

```bash
# 1. Homebrew (chezmoi does not install it).
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install chezmoi

# 2. A GitHub SSH key; the clone and all pushes use SSH.
ssh-keygen -t ed25519 -a 100 -N "" -f ~/.ssh/id_ed25519
pbcopy < ~/.ssh/id_ed25519.pub
#    Add it under GitHub → Settings → SSH and GPG keys, then check:
ssh -T git@github.com

# 3. Clone and apply. Asks for the machine name (mca, gza, ...).
chezmoi init --apply git@github.com:dolfth/dotfiles.git
```

The machine name is stored as `computerName` in
`~/.config/chezmoi/chezmoi.toml`. The first apply asks for sudo once, for the
system-settings script. That script skips itself without a terminal; if it
was skipped, run `chezmoi apply` in one.

Do **not** `chsh` to fish. `~/.zshrc` starts fish for interactive sessions,
so `$SHELL` stays POSIX for software that runs `$SHELL -c '...'`. fish's docs
recommend this.

## Layout

### Files

| Source | Target | Notes |
|---|---|---|
| `.chezmoi.toml.tmpl` | `~/.config/chezmoi/chezmoi.toml` | asks for the machine name (macOS) |
| `dot_Brewfile.tmpl` | `~/.Brewfile` | all installed software; omlx on the desktop only, which otherwise gets just CLI tools, Tailscale and Ghostty |
| `dot_zshrc` | `~/.zshrc` | macOS only; starts fish |
| `private_dot_ssh/private_config` | `~/.ssh/config` | macOS only; SSH key passphrases in the Keychain |
| `dot_config/fish/config.fish` | `~/.config/fish/config.fish` | |
| `dot_config/fish/functions/up.fish` | `~/.config/fish/functions/up.fish` | macOS only; `up` updates CLT, brew and App Store apps, restarts omlx if upgraded |
| `dot_config/starship.toml.tmpl` | `~/.config/starship.toml` | per-host accent |
| `dot_config/git/config` | `~/.config/git/config` | |
| `dot_config/nvim/init.lua` | `~/.config/nvim/init.lua` | lazy.nvim |
| `dot_config/ghostty/config` | `~/.config/ghostty/config` | Nerd Font, so starship glyphs render |
| `dot_config/herdr/config.toml` | `~/.config/herdr/config.toml` | |
| `dot_omlx/` | `~/.omlx/` | desktop only; omlx settings and model profiles, server aliases for the host's `.local` and Tailscale names |
| `dot_pi/agent/modify_settings.json` | `~/.pi/agent/settings.json` | merges into the file pi writes |
| `private_Library/LaunchAgents/com.dolfth.omlx.plist.tmpl` | `~/Library/LaunchAgents/` | desktop only; keeps `omlx serve` running, unthrottled |

### Scripts

| Script | Runs | Does |
|---|---|---|
| `run_onchange_before_10-brew-bundle.sh.tmpl` | macOS, when the rendered Brewfile changes, before files | `brew bundle` install and cleanup |
| `run_after_20-macos-defaults.sh.tmpl` | macOS, every apply, so manual changes are reverted | user defaults: Dock, Finder, keyboard, trackpad, apps |
| `run_onchange_30-macos-system-settings.sh.tmpl` | macOS, when the script changes; needs a terminal | sudo: hostname, firewall, Touch ID for sudo, guest account, login window, power, software updates, FileVault check; desktop: GPU wired memory limit (LaunchDaemon), Screen Sharing, Remote Login |
| `run_onchange_35-herdr-plugins.sh.tmpl` | where herdr is installed, when the script changes | installs the herdr plugins the keybindings use |
| `run_onchange_after_40-omlx-agent.sh.tmpl` | desktop, when the plist changes, after files | (re)loads the omlx LaunchAgent |

Removing a line from a settings script stops setting that value; it does not
restore the old one. Files that moved are deleted via `.chezmoiremove`.

## Desktop after a power cut

With FileVault on, the desktop stops at the unlock screen and nothing runs.
Unlock it over SSH (Apple silicon, macOS 26+):

```bash
ssh dolf@gza.local   # account password; SSH keys don't work at this stage
```

The connection drops while macOS finishes booting; then omlx, SSH and Screen
Sharing are available.

## Day to day

```bash
chezmoi edit ~/.zshrc   # edit the source, not the target
chezmoi diff            # preview changes
chezmoi apply           # apply; also re-runs the defaults script
chezmoi update          # git pull, then apply
chezmoi cd              # shell in this repo
```
