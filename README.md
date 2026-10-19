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
`git commit -am "…"; git push`; the other machines pull. The remote is
`git@github.com:dolfth/dotfiles.git` -- `main` is the mise era, the pre-mise
chezmoi iteration lives on under `archive/chezmoi`.

## Config layout

| File | Loads when | Holds |
|---|---|---|
| `mise.toml` | always | per-host data in `[vars]` (accent/icon/tailnet/sshKeys), the shared dotfiles, the bootstrap hooks |
| `mise.mac.toml` | `mac` selected | both Macs: the declarative macOS defaults, `~/.zshrc`, `~/.ssh/config`, `up.fish`, linearmouse |
| `mise.mca.toml` | `mca` selected | the laptop: the syncthing user service (its GUI software lives in `Brewfile.mca`) |
| `mise.gza.toml` | `gza` selected | the desktop: the omlx + splash LaunchAgents, the agent self-heal, the omlx, omp and pi configs (its formulae live in `Brewfile.gza`) |
| `mise.nwa.toml` | `nwa` selected | the omp, pi and herdr configs (mise on nwa comes from Nix, not a package list) |
| `miserc.local.toml` | not committed | this machine: `env = ["mac", "<host>"]` |
| `Brewfile`, `Brewfile.mca`, `Brewfile.gza` | the brew-bundle task (Macs) | the brew-ecosystem manifest per machine (see below) |

Selecting the environments in `miserc.local.toml` loads the module files
(`mise.<env>.toml`); everything else in the config is environment-neutral.

## Bootstrap a Mac

```bash
xcode-select --install   # 1. Command Line Tools (a stub on a clean Mac); git and Homebrew reuse them
ssh-keygen -t ed25519 -a 100 -N "" -C gza -f ~/.ssh/id_ed25519   # 2. GitHub key; -C names the machine
pbcopy < ~/.ssh/id_ed25519.pub   # add under GitHub → Settings → SSH and GPG keys
ssh -T git@github.com
curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | bash   # 3. brew
brew install mise   # 4. mise itself
mise bootstrap --adopt 'git@github.com:dolfth/dotfiles.git?ref=main' -E mac,gza   # 5. everything else
```

Step 3 needs sudo, then follow the "shells" note it prints (on Apple silicon
an `eval "$(/opt/homebrew/bin/brew shellenv)"` line in `~/.zprofile`) so brew
is on PATH in new shells. Step 5 clones this repo into `~/.config/mise` (the
global mise config) and runs bootstrap: the pre-packages hooks take the
defaults snapshot and run `brew bundle` over the Brewfiles, the dotfiles
deploy, the launchd agents register (the `bootstrap` task self-heals them),
and the final hooks run the system settings (the sudo part is TTY-gated and
skipped without a terminal -- re-run `mise run system-check` in one) plus the
herdr and vscodium extensions.

The `-E mac,gza` lands in `~/.config/mise/miserc.local.toml`, and every later
mise command on the machine uses it (select `-E mac,mca` on the laptop).

Do **not** `chsh` to fish: `~/.zshrc` starts fish for interactive sessions,
so `$SHELL` stays POSIX for software that runs `$SHELL -c '...'`.

## Bootstrap nwa

nwa's OS comes from its NixOS flake, which declares mise (reading this
checkout with `env = ["nwa"]`); the first `mise bootstrap` deploys the omp
config. After that, nwa follows this repo like the Macs.

## Layout

### Packages (the Brewfiles)

| What | Where |
|---|---|
| 18 formulae (incl. mise) + 3 casks, both Macs | `Brewfile` |
| 18 GUI casks + 2 formulae (aerospace borders, syncthing) + 7 App Store apps, laptop only | `Brewfile.mca` |
| omlx + splash + omp, desktop only | `Brewfile.gza` |

`brew bundle` (the brew-bundle task) installs what is missing and never
upgrades what is present -- daily upgrades go through `up`. App Store entries
(`mas`) require being signed in, and the app in your purchase history.

### Why brew + mise (and not all-mise)

mise cannot install the desktop's omlx, splash and omp: its formula-metadata
shim doesn't implement the brew DSL their tap definitions use, and its
source-build shim rejects omp's `with_env`; resolution is all-or-nothing per
batch, so one unresolvable formula fails the whole step. One owner per
ecosystem instead:

- **brew** owns the brew-ecosystem: the Brewfiles above are the manifest,
  `brew bundle` installs, `up` upgrades. brew evaluates its own formulas
  natively, so all of them work as-is.
- **mise** owns the rest: the dotfiles (merge and template support), the
  tasks and bootstrap hooks, the launchd agents, the declarative macOS
  defaults, declared tool versions -- plus itself, as a brew formula.

brew adopts the kegs the mise era already poured -- no reinstall. The
all-mise fallback (the hand-rolled tap bridge) is in the git history; if
mise's shim gaps get fixed upstream, dropping brew is deleting the Brewfiles
and the task.

### Files (`[dotfiles]`)

| Source | Target | Notes |
|---|---|---|
| `zshrc` | `~/.zshrc` | both Macs; starts fish |
| `ssh_config` | `~/.ssh/config` | both Macs, copied at 0600 (a symlink would expose the repo file's permissions to ssh); key passphrases in the Keychain |
| `fish/config.fish` | `~/.config/fish/config.fish` | all machines; the mise activation block |
| `fish/functions/up.fish` | `~/.config/fish/functions/up.fish` | both Macs; nwa's home-manager owns its own functions there |
| `starship.toml.tera` | `~/.config/starship.toml` | per-host accent and icon from the vars |
| `git/config` | `~/.config/git/config` | signs commits and tags with `~/.ssh/id_ed25519` |
| `git/allowed_signers.tera` | `~/.config/git/allowed_signers` | every host's public key (the `sshKeys` var) |
| `nvim/init.lua` | `~/.config/nvim/init.lua` | lazy.nvim |
| `ghostty/config` | `~/.config/ghostty/config` | Nerd Font, so starship glyphs render |
| `herdr/config.toml` | `~/.config/herdr/config.toml` | nwa only; copied -- herdr rewrites the file itself |
| `linearmouse/linearmouse.json` | `~/.config/linearmouse/linearmouse.json` | both Macs; written only if absent, then LinearMouse owns it |
| `pi/agent/settings.json` | `~/.pi/agent/settings.json` | gza + nwa; two pinned keys deep-merged into the file pi writes |
| `omlx/*.json` | `~/.omlx/` | gza; the pinned settings, model settings and profiles deep-merged into the files omlx writes (auth keys stay omlx's), plus server aliases for the host's `.local` and Tailscale names |
| `omp/agent/config.yml` | `~/.omp/agent/config.yml` | gza + nwa, symlinked: `/settings` changes flow back into the repo -- commit them |
| `omp/agent/models.yml.tera` | `~/.omp/agent/models.yml` | gza + nwa; the omlx + splash providers; `baseUrl` is `127.0.0.1` on gza, `gza` (Tailscale) elsewhere |

Rows without a host apply to all machines. Files on disk that are not
declared in the loaded modules are left alone; `mise dot prune` removes
ones the repo used to track. To delete a file the repo deployed, declare it
`mode: absent` in the module that used to.

### Tasks and hooks (`mise-tasks/`)

| Task | Hook | Does |
|---|---|---|
| `defaults-snapshot` | pre-packages | hashes the defaults domains the UI reads, before bootstrap writes them |
| `brew-bundle` | pre-packages | `brew bundle` over `Brewfile` + `Brewfile.<host>`: installs what is missing, never upgrades (`up` does); a failed entry warns and continues (re-run `brew bundle` in a terminal). No-op off macOS |
| `bootstrap` | the bootstrap task slot | for each `dev.mise.*` LaunchAgent: a guarded `launchctl bootstrap` (only (re)loads a not-loaded job) + a bare `kickstart` (starts a dead agent, no-op on a healthy one -- never kills a running server); then reports who holds each port. No-op off gza |
| `herdr-plugins` | final | the herdr plugins the keybindings and nvim config rely on; no-op where herdr is absent |
| `vscode-extensions` | final | the vscodium extensions; no-op where codium is absent |
| `system-check` | final | the macOS system settings: FDA-gated app defaults, hostname, firewall, Touch ID, power, updates, FileVault check, the GPU wired-limit daemon; the desktop gets Screen Sharing + Remote Login. The sudo part is TTY-gated. Restarts Dock/Finder/… only when a domain they read changed |

They run on every `mise bootstrap` / `mise update` and no-op when there is
nothing to do.

### Desktop services (gza)

`omlx serve` (8080, `::`) and `splash serve` (8000, `127.0.0.1`) run as user
LaunchAgents in `mise.gza.toml` (`dev.mise.*`, `ProcessType: Interactive`,
unthrottled): KeepAlive keeps them alive, bootstrap reloads them when their
definition changes, the `bootstrap` task self-heals a dead one on every
bootstrap and reports who holds each port, and `up` restarts a server whose
keg was upgraded. Logs: `~/Library/Logs/{omlx,splash}.log`.

splash is loopback only; for LAN or tailnet access serve with `--host
0.0.0.0 --api-key KEY --allowed-origin '*'` (or `--allowed-host
gza.<tailnet>`). The chat page is at <http://127.0.0.1:8000>.

## Day to day

```bash
cd ~/.config/mise          # the repo; the mise config reads from here
mise bootstrap             # apply everything (hooks + packages + dotfiles)
mise dot status            # the file list; `mise dot diff` previews
git commit -am "…"; git push
```

Edit a template and run `mise dot apply` to re-render it; `mise dot diff`
shows what would change first.
