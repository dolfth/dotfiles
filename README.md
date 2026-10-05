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
# 1. Command Line Tools, for git. /usr/bin/git on a clean Mac is a stub that
#    only offers this install; Homebrew reuses them later.
xcode-select --install

# 2. A GitHub SSH key; the clone and all pushes use SSH.
#    -C sets the key comment to the machine name. Without it ssh-keygen uses
#    user@host, or whatever email it picks up, and GitHub stores it.
ssh-keygen -t ed25519 -a 100 -N "" -C mca -f ~/.ssh/id_ed25519   # mca, gza, ...
pbcopy < ~/.ssh/id_ed25519.pub
#    Add it under GitHub → Settings → SSH and GPG keys, then check:
ssh -T git@github.com

# 3. Everything else. Downloads a throwaway chezmoi into $TMPDIR, clones
#    git@github.com:dolfth/dotfiles.git (--ssh) and applies. The first script
#    installs Homebrew, whose Brewfile then installs the real chezmoi. Asks
#    for the machine name (mca, gza, ...).
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$TMPDIR" init --apply --ssh dolfth
```

The machine name is stored as `computerName` in
`~/.config/chezmoi/chezmoi.toml`. The first apply asks for sudo for the Homebrew
install and once more for the system-settings script. That script skips itself without a terminal; if it
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
| `dot_config/fish/exact_functions/up.fish` | `~/.config/fish/functions/up.fish` | macOS only; exact: other files in that directory are deleted; `up` updates CLT, brew and App Store apps, restarts omlx if upgraded |
| `dot_config/starship.toml.tmpl` | `~/.config/starship.toml` | per-host accent |
| `dot_config/git/config` | `~/.config/git/config` | signs commits and tags with `~/.ssh/id_ed25519` |
| `dot_config/git/allowed_signers.tmpl` | `~/.config/git/allowed_signers` | every host's public key (`sshKeys` in `.chezmoidata.yaml`), for verifying signatures |
| `dot_config/nvim/init.lua` | `~/.config/nvim/init.lua` | lazy.nvim |
| `dot_config/ghostty/config` | `~/.config/ghostty/config` | Nerd Font, so starship glyphs render |
| `dot_config/herdr/config.toml` | `~/.config/herdr/config.toml` | |
| `dot_config/linearmouse/create_linearmouse.json` | `~/.config/linearmouse/linearmouse.json` | written only if missing; after that LinearMouse owns it |
| `dot_omlx/modify_*.json.tmpl` | `~/.omlx/` | desktop only; merge the pinned omlx settings, model settings and profiles into the files omlx writes (auth keys stay omlx's, not in this repo); server aliases for the host's `.local` and Tailscale names |
| `dot_pi/agent/modify_settings.json` | `~/.pi/agent/settings.json` | merges into the file pi writes |
| `private_Library/LaunchAgents/com.dolfth.omlx.plist.tmpl` | `~/Library/LaunchAgents/` | desktop only; keeps `omlx serve` running, unthrottled |

### Scripts

In `.chezmoiscripts/`, which creates no directory in `~`.

| Script | Runs | Does |
|---|---|---|
| `run_once_before_00-homebrew.sh.tmpl` | macOS, once per machine, before files; needs a terminal | installs Homebrew if missing |
| `run_onchange_before_10-brew-bundle.sh.tmpl` | macOS, when the rendered Brewfile changes, before files | `brew bundle` install and cleanup |
| `run_after_20-macos-defaults.sh.tmpl` | macOS, every apply, so manual changes are reverted | user defaults: Dock, Finder, keyboard, trackpad, apps; registers noTunes as a login item (autostart) |
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
