# dotfiles

[mise](https://mise.jdx.dev) for three machines:

| Host | OS | Role |
|---|---|---|
| `mca` | macOS | laptop |
| `gza` | macOS | desktop, always-on omlx and splash servers, omp |
| `nwa` | NixOS | server |

Everything a machine needs -- packages, dotfiles, and the settings tasks
(mise tasks and the bootstrap hooks) -- lives in this one checkout, which
*is* the global mise config, so it doubles as the dotfile history: edit,
`git commit`, push; the other machines pull it.

## Config layout

| File | Loads when | Holds |
|---|---|---|
| `mise.toml` | always | per-host data in `[vars]` (accent/icon/kind/tailnet/sshKeys), shared dotfiles, bootstrap hooks |
| `mise.mac.toml` | `mac` selected | both Macs: CLI tools, the declarative macOS defaults, `~/.zshrc`, `~/.ssh/config`, `up.fish` |
| `mise.mca.toml` | `mca` selected | laptop: GUI casks, App Store, noTunes, syncthing |
| `mise.gza.toml` | `gza` selected | desktop: omlx + splash, the LaunchAgents, the agent cutover, merged omlx/omp configs |
| `mise.nwa.toml` | `nwa` selected | the omp agent config (mise on nwa comes from Nix, not from a package list) |
| `miserc.local.toml` | not committed | this machine: `env = ["mac", "<host>"]` |

Selecting the environments in `miserc.local.toml` loads the module files
(`mise.<env>.toml`); everything else in the config is environment-neutral.

## Bootstrap a Mac

```bash
# 1. Command Line Tools, for git. /usr/bin/git on a clean Mac is a stub that
#    only offers this install; Homebrew reuses them later.
xcode-select --install

# 2. A GitHub SSH key; the clone and all pushes use SSH.
#    -C sets the key comment to the machine name. Without it ssh-keygen uses
#    user@host, or whatever email it picks up, and GitHub stores it.
ssh-keygen -t ed25519 -a 100 -N "" -C gza -f ~/.ssh/id_ed25519   # mca, gza, ...
pbcopy < ~/.ssh/id_ed25519.pub
#    Add it under GitHub → Settings → SSH and GPG keys, then check:
ssh -T git@github.com

# 3. mise itself, for the bootstrap command below. The bootstrap's packages
# step then installs mise into the Homebrew prefix (brew:mise in the mac
# module) -- the copy in the prefix is the one that stays, so delete the
# curl-installed one afterwards (step 5).
curl -fsSL https://mise.run | sh
export PATH="$HOME/.local/bin:$PATH"   # or start a new shell

# 4. Everything else. Clones this repo into ~/.config/mise (the global mise
#    config) and runs bootstrap from it: the pre-packages hooks take the
#    defaults snapshot and, on the desktop, pre-install omlx and splash (the
#    two formulae the current mise release cannot evaluate -- see the
#    tasks table), the packages step installs the modules' packages into
#    the Homebrew prefix (no Homebrew installation needed; mise creates
#    the prefix on first use), the dotfiles deploy, and the final hooks run
#    the system settings, the herdr and vscodium extensions. Asks for sudo
#    (the prefix, system settings) and, if the machine has no terminal, it
#    skips the TTY-gated parts; re-run `mise run system-check` in one.
mise bootstrap --adopt 'git@github.com:dolfth/dotfiles.git?ref=main' -E mac,gza
# 5. The curl-installed mise in ~/.local/bin is a duplicate of what the
#    packages step just installed in the prefix -- delete it so there is
#    exactly one mise.
rm -f ~/.local/bin/mise
```

The environment selection (`-E mac,gza`) is written into
`~/.config/mise/miserc.local.toml` by the step below, and from then on every
mise command on the machine uses it. If your machine name is not `gza`,
select its module instead (`-E mac,mca`).

Do **not** `chsh` to fish. `~/.zshrc` starts fish for interactive sessions,
so `$SHELL` stays POSIX for software that runs `$SHELL -c '...'`. fish's docs
recommend this.

## Bootstrap nwa

nwa's OS comes from its NixOS flake. The flake declares mise (which reads
this checkout at `~/.config/mise`, `env = ["nwa"]`), then the first
`mise bootstrap` deploys the omp config. After that, nwa follows this repo
like the Macs.

## Layout

### Packages (`[bootstrap.packages]` in the host modules)
| What | Where |
|---|---|
| 19 formulae + 3 casks both Macs share (git, fish, neovim, starship, …, tailscale-app, ghostty) | `mise.mac.toml` |
| 18 GUI casks + 2 formulae (aerospace borders, syncthing) + 7 App Store apps, laptop only | `mise.mca.toml` |
| omlx + splash, desktop only (omp is deliberately not a package -- see the note below) | `mise.gza.toml` |

App Store IDs come from `mas list`, or the trailing digits of the App Store
URL. They require being signed in, and the app must already be in your
purchase history.

The formulae and casks install into the standard Homebrew prefix, but no
Homebrew installation is required: mise creates the prefix on first use and
keeps the layout (Cellar, opt, receipts) brew-compatible, so a Homebrew that
exists or appears later coexists -- mise never overwrites prefix files it did
not create, and it counts a keg linked into `opt/` as installed no matter
who poured it.

One wrinkle: the current mise release (2026.10.14) cannot evaluate three of
the tap formulas. The omlx and splash definitions use constructs its formula
metadata shim lacks (`MacOS` constant, `Requirement` class), and omp's
install step uses `with_env`, which its source-build shim rejects outright --
so a run that resolves any of them dies on them. The bridges, until the
upstream fixes land: `omlx-splash` pre-installs both server kegs on a fresh
machine (the bootstrap's pre-packages hook) and, since a clean machine has no
Homebrew, is the only way omp gets installed there at all; `packages-upgrade`
names every resolvable formula for the daily `up`; and `up` itself carries a
Homebrew-bridge block (`brew upgrade omlx splash` + a reinstall of omp) for
machines that *do* have Homebrew. Delete the pieces as the fixes ship.

### Files (`[dotfiles]`)

| Source | Target | Notes |
|---|---|---|
| `zshrc` | `~/.zshrc` | both Macs (the mac module); starts fish |
| `ssh_config` | `~/.ssh/config` | both Macs, mode `copy` at 0600; SSH key passphrases in the Keychain |
| `fish/config.fish` | `~/.config/fish/config.fish` | all machines (the mise activation block) |
| `fish/functions/up.fish` | `~/.config/fish/functions/up.fish` | both Macs; nwa's home-manager writes its own functions there, so not on nwa |
| `starship.toml.tera` | `~/.config/starship.toml` | per-host accent and icon from the vars, template `tera` |
| `git/config` | `~/.config/git/config` | signs commits and tags with `~/.ssh/id_ed25519` |
| `git/allowed_signers.tera` | `~/.config/git/allowed_signers` | every host's public key (the `sshKeys` var), template `tera` |
| `nvim/init.lua` | `~/.config/nvim/init.lua` | lazy.nvim |
| `ghostty/config` | `~/.config/ghostty/config` | Nerd Font, so starship glyphs render |
| `herdr/config.toml` | `~/.config/herdr/config.toml` | mode `copy`: herdr rewrites the file itself |
| `linearmouse/linearmouse.json` | `~/.config/linearmouse/linearmouse.json` | `merge: missing`: written only if absent, then LinearMouse owns it |
| `pi/agent/settings.json` | `~/.pi/agent/settings.json` | `merge`: the two pinned keys over the file pi writes |
| `omlx/*.json` | `~/.omlx/` | gza only; `merge` + `template`: the pinned omlx settings, model settings and profiles deep-merged into the files omlx writes (auth keys stay omlx's, not in this repo); server aliases for the host's `.local` and Tailscale names |
| `omp/agent/config.yml` | `~/.omp/agent/config.yml` | gza + nwa (symlink); omp's own settings -- `/settings` changes flow back into this repo through the symlink, so commit them |
| `omp/agent/models.yml.tera` | `~/.omp/agent/models.yml` | gza + nwa (template); the omlx + splash providers omp talks to; `baseUrl` is `127.0.0.1` on gza, `gza` (Tailscale) elsewhere |

Files that exist on disk but are not declared in the loaded modules are
left alone; `mise dot prune` removes ones the repo used to track. To delete
an old file the repo deployed, declare it with `mode: absent` in the module
that used to deploy it.

### Tasks and hooks (`mise-tasks/`)

| Task | Hook | Does |
|---|---|---|
| `defaults-snapshot` | pre-packages (always) | hashes the defaults domains the UI reads, before bootstrap writes them |
| `omlx-splash` | pre-packages (always) | installs the omlx + splash kegs the current mise release cannot resolve, on the host that declares them (gza); no-op elsewhere and wherever the kegs already exist (`MISE_OMLX_SPLASH_FORCE=1` replaces them -- the upgrade path on a machine without Homebrew) |
| `packages-upgrade` | none (the `up` function) | the daily mise-side upgrade: every resolvable formula of the Mac modules, named, so the omlx, splash and omp definitions mise cannot evaluate stay out (their upgrades live in the `up` function's Homebrew-bridge block and the omlx-splash task) |
| `bootstrap` | the bootstrap task slot (always) | the LaunchAgent cutover: registers the `dev.mise.*` agents, boots out `com.dolfth.*` jobs if launchd still has them, kickstarts the new ones; no-op off gza (it never kills a process holding a port -- the agent retries under KeepAlive until it frees up) |
| `herdr-plugins` | final (always) | installs the herdr plugins the keybindings and nvim config rely on; no-op where herdr is absent |
| `vscode-extensions` | final (always) | the vscodium extensions; no-op where codium is absent (i.e. everywhere but mca) |
| `system-check` | final (always) | the macOS system settings: FDA-gated app defaults, the hostname, firewall, Touch ID, power, software updates, FileVault check, the GPU wired-limit daemon; desktop: Screen Sharing and Remote Login. The sudo part is TTY-gated. Re-starts Dock/Finder/… only if a domain they read changed |

The tasks run on **every** bootstrap (`mise bootstrap` / `mise update`);
they are all written to no-op when there is nothing to do.

### Desktop services (gza)

`omlx serve` (port 8080, `::`) and `splash serve` (port 8000, `127.0.0.1`)
run as user LaunchAgents declared in `mise.gza.toml`
(`dev.mise.omlx`, `dev.mise.splash`, both `ProcessType: Interactive`,
unthrottled). mise keeps them alive, and the `bootstrap` task re-kickstarts
them on every bootstrap, so no hand `launchctl` dance. Logs:
`~/Library/Logs/{omlx,splash}.log`.

splash is loopback only — for LAN or tailnet access serve with
`--host 0.0.0.0 --api-key KEY --allowed-origin '*'` (or `--allowed-host
gza.<tailnet>`); the chat page is at <http://127.0.0.1:8000>.

## Day to day

```bash
cd ~/.config/mise          # the repo; the mise config reads from here
mise bootstrap             # apply everything (hooks + packages + dotfiles)
mise dot status            # the file list; `mise dot diff` previews
git commit -am "…"; git push
```

Edit a template and run `mise dot apply` to re-render it; `mise dot diff` shows
what would change first.
