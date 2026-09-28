# dotfiles

chezmoi source for `mca` (macOS) and `nwa` (NixOS). Everything here manages
`~`; privileged, machine-specific state (hostname, firewall, power) is applied
by a script, not stored in the repo.

## Bootstrap on a Mac

```bash
# 1. Homebrew — chezmoi does not install it, and neither did nix-darwin.
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install chezmoi

# 2. A GitHub SSH key — pulls and pushes both go over SSH, so create one
#    before the clone:
#
#      ssh-keygen -t ed25519 -a 100 -N "" -f ~/.ssh/id_ed25519
#      pbcopy < ~/.ssh/id_ed25519.pub
#
#    Paste the public half into GitHub → Settings → SSH and GPG keys, then
#    verify with `ssh -T git@github.com` ("Hi dolfth!"). Only the public key
#    leaves the machine; the private half is what GitHub challenges.

# 3. This repo. --apply does the first apply immediately; origin is set to
#    the same SSH URL, so `git push` works from day one.
chezmoi init --apply git@github.com:dolfth/dotfiles.git
```

On macOS, `init` first asks for the machine name (e.g. `mca`, `gza`); it is
saved as `computerName` under `[data]` in `~/.config/chezmoi/chezmoi.toml` and
selects the host's entry in `.chezmoidata.yaml` (prompt accent, and `kind:
laptop | desktop`: the power profile, the Brewfile, and whether the Mac runs
omlx as an always-on server). A new Mac needs an entry there first;
unknown hosts get the fallback accent and the laptop power profile.

The first apply then prompts for sudo once: the system-settings script sets
the hostname, firewall, Touch ID for sudo, guest account, login window, and
power, and checks FileVault. If you skipped the prompt, run `chezmoi apply`
in a terminal — it skips itself in non-interactive contexts.

Do **not** `chsh` to fish. `~/.zshrc` hands off to it for interactive
sessions, which keeps `$SHELL` POSIX — lots of software runs
`$SHELL -c '<posix syntax>'` and fish is not POSIX. This is what fish's own
docs recommend.

## Layout

### Dotfiles

- `.chezmoi.toml.tmpl` → `~/.config/chezmoi/chezmoi.toml` — asks for the machine name on `chezmoi init` (macOS)
- `.chezmoidata.yaml` — per-host data: prompt accent/icon, Mac `kind` (laptop/desktop)
- `dot_Brewfile.tmpl` → `~/.Brewfile` — the single source of truth for installed software; the desktop gets CLI tools, tailscale and Ghostty only
- `dot_config/git/config` → `~/.config/git/config`
- `private_Library/LaunchAgents/com.dolfth.omlx.plist.tmpl` → `~/Library/LaunchAgents/` — desktop only; runs `omlx serve` unthrottled (ProcessType Interactive) and restarts it if it dies
- `dot_zshrc` → `~/.zshrc` — macOS only; hands off to fish
- `dot_config/fish/config.fish` → `~/.config/fish/config.fish`
- `dot_config/starship.toml.tmpl` → `~/.config/starship.toml` — per-host accent from `.chezmoidata.yaml`
- `dot_config/nvim/init.lua` → `~/.config/nvim/init.lua` — lazy.nvim; ported from nixvim
- `dot_pi/agent/modify_settings.json` → `~/.pi/agent/settings.json` — **merges** into what pi writes
- `dot_config/ghostty/config` → `~/.config/ghostty/config` — Nerd Font family so starship's PUA glyphs render

### Scripts

- `run_onchange_before_10-brew-bundle.sh.tmpl` — runs `brew bundle` when `.Brewfile` changes, before the apply
- `run_after_20-macos-defaults.sh.tmpl` — user defaults (Dock, Finder, typing, trackpad, per-app settings); runs on **every** apply so hand-flipped settings get put back
- `run_onchange_30-macos-system-settings.sh.tmpl` — sudo settings (hostname, firewall, Touch ID, guest account, login window, power by `kind`, no automatic macOS updates, Screen Sharing and Remote Login (SSH FileVault unlock) on the desktop, FileVault check); runs on first apply and when the script changes, needs a terminal
- `run_onchange_40-omlx-agent.sh.tmpl` — desktop only; (re)loads the omlx LaunchAgent when its plist changes
- `run_onchange_35-herdr-plugins.sh.tmpl` — installs the herdr plugins the `dot_config/herdr` keybindings point at (nvim sidebar, tab auto-rename); runs when the script changes, skips where herdr is absent

## Day to day

```bash
chezmoi edit ~/.zshrc     # edit the source, not the target
chezmoi diff              # what would change
chezmoi apply             # apply, re-running the defaults script
chezmoi update            # git pull + apply
chezmoi cd                # shell in this repo
```
