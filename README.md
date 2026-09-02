# dotfiles

chezmoi source for `mca` (macOS) and `nwa` (NixOS). Everything here manages
`~`; privileged, machine-specific state (hostname, firewall, power) is applied
by a script, not stored in the repo.

## Bootstrap on a Mac

```bash
# 1. Homebrew — chezmoi does not install it, and neither did nix-darwin.
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install chezmoi

# 2. This repo. --apply does the first apply immediately.
chezmoi init --apply git@github.com:dolfth/dotfiles.git
```

The first apply then prompts for sudo once: the system-settings script sets
the hostname, firewall, Touch ID for sudo, guest account, login window, and
power, and checks FileVault. If you skipped the prompt, run `chezmoi apply`
in a terminal — it skips itself in non-interactive contexts. The hostname is
derived from the machine's own name (`mca.local` → `mca`) so the starship
accent matches `.chezmoidata.yaml`; override it with `computerName = "..."`
under `[data]` in `~/.config/chezmoi/chezmoi.toml`.

Do **not** `chsh` to fish. `~/.zshrc` hands off to it for interactive
sessions, which keeps `$SHELL` POSIX — lots of software runs
`$SHELL -c '<posix syntax>'` and fish is not POSIX. This is what fish's own
docs recommend.

## Layout

### Dotfiles

- `dot_Brewfile` → `~/.Brewfile` — the single source of truth for installed software
- `dot_gitconfig` → `~/.gitconfig`
- `dot_zshrc` → `~/.zshrc` — macOS only; hands off to fish
- `dot_config/fish/config.fish` → `~/.config/fish/config.fish`
- `dot_config/starship.toml.tmpl` → `~/.config/starship.toml` — per-host accent from `.chezmoidata.yaml`
- `dot_config/nvim/init.lua` → `~/.config/nvim/init.lua` — lazy.nvim; ported from nixvim
- `dot_pi/agent/modify_settings.json` → `~/.pi/agent/settings.json` — **merges** into what pi writes

### Scripts

- `run_onchange_before_10-brew-bundle.sh.tmpl` — runs `brew bundle` when `.Brewfile` changes, before the apply
- `run_after_20-macos-defaults.sh.tmpl` — user defaults (Dock, Finder, typing, trackpad, per-app settings); runs on **every** apply so hand-flipped settings get put back
- `run_onchange_30-macos-system-settings.sh.tmpl` — sudo settings (hostname, firewall, Touch ID, guest account, login window, power, FileVault check); runs on first apply and when the script changes, needs a terminal

## Day to day

```bash
chezmoi edit ~/.zshrc     # edit the source, not the target
chezmoi diff              # what would change
chezmoi apply             # apply, re-running the defaults script
chezmoi update            # git pull + apply
chezmoi cd                # shell in this repo
```
