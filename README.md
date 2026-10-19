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
| `mise.mac.toml` | `mac` selected | both Macs: the declarative macOS defaults, `~/.zshrc`, `~/.ssh/config`, `up.fish` |
| `mise.mca.toml` | `mca` selected | laptop: the syncthing user service (the GUI software lives in `Brewfile.mca`) |
| `mise.gza.toml` | `gza` selected | desktop: the omlx + splash LaunchAgents, the agent cutover, merged omlx/omp configs (the brew formulae live in `Brewfile.gza`) |
| `mise.nwa.toml` | `nwa` selected | the omp agent config (mise on nwa comes from Nix, not from a package list) |
| `miserc.local.toml` | not committed | this machine: `env = ["mac", "<host>"]` |
| `Brewfile`, `Brewfile.mca`, `Brewfile.gza` | the brew-bundle bootstrap task (Macs) | the brew-ecosystem manifest: the 19 formulae (incl. mise) + 3 casks both Macs share; the laptop's GUI casks, 2 formulae and 7 App Store apps; the desktop's omlx, splash, omp |

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

# 3. Homebrew, the brew-ecosystem installer (a bootstrap dependency on the
#    Macs -- see "Why brew + mise" below). The installer needs sudo, then
#    follow the "shells" note it prints (on Apple silicon an
#    `eval "$(/opt/homebrew/bin/brew shellenv)"` line in ~/.zprofile) so
#    brew is on PATH in new shells.
curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | bash
brew install mise   # 4. mise itself, from brew.

# 5. Everything else. Clones this repo into ~/.config/mise (the global mise
#    config) and runs bootstrap from it: the pre-packages hooks take the
#    defaults snapshot and run `brew bundle` over the Brewfiles (the
#    brew-ecosystem packages, incl. the desktop's omlx, splash and omp), the
#    dotfiles deploy, the launchd agents register, and the final hooks run
#    the system settings, the herdr and vscodium extensions. Asks for sudo
#    (the system settings) and, if the machine has no terminal, it skips the
#    TTY-gated parts; re-run `mise run system-check` in one.
mise bootstrap --adopt 'git@github.com:dolfth/dotfiles.git?ref=main' -E mac,gza
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

### Packages (the Brewfiles)

| What | Where |
|---|---|
| 19 formulae (incl. mise) + 3 casks both Macs share (git, fish, neovim, starship, …, ghostty, tailscale-app) | `Brewfile` |
| 18 GUI casks + 2 formulae (aerospace borders, syncthing) + 7 App Store apps, laptop only | `Brewfile.mca` |
| omlx + splash + omp, desktop only | `Brewfile.gza` |

App Store entries (`mas`) require being signed in, and the app must already
be in your purchase history; the IDs come from `mas list`, or the trailing
digits of the App Store URL.

brew bundle (the bootstrap's brew-bundle task) installs what is missing and
does not upgrade what is present; daily upgrades go through `up`. The kegs
land in the standard Homebrew prefix, which is why Homebrew is a bootstrap
step on the Macs.

### Why brew + mise (and not all-mise)

This repo first landed fully on mise, with the brew-ecosystem packages
declared in the modules' `[bootstrap.packages]` -- until the current mise
release (2026.10.14, the one this migration used) turned out to be unable to
handle three of the formulae:

- the **omlx** and **splash** tap definitions use brew DSL constructs mise's
  formula-metadata shim does not implement (a `MacOS` constant, a
  `Requirement` class, `unavailable:`), so mise cannot resolve them;
- **omp**'s install step uses `with_env`, which mise's source-build shim
  rejects outright;
- and resolution is all-or-nothing per batch: one unresolvable formula fails
  the whole packages step.

The previous revision bridged the gap by hand -- a task replicating the two
live tap formulas line for line, a named upgrade list, a brew-bridge block in
`up` -- which had to be re-synced every time an upstream formula changed a
pin, a resource or a build step. That tax is paid on real machines, while the
only thing it bought was a fresh Mac without Homebrew; this fleet has none
(both Macs run Homebrew, nwa is Nix and needs no package manager at all).

So on 2026-10-19 the split became the standard one, one owner per
ecosystem:

- **brew** owns the brew-ecosystem: the Brewfiles above are the manifest,
  `brew bundle` installs, `up` upgrades. brew evaluates its own formulas
  natively, so all of the above formulae work as-is (omp installed from its
  renamed tap in 12 seconds when the cutover was tested).
- **mise** owns the rest: the dotfiles (with merge and template support),
  the tasks and bootstrap hooks, the launchd agents, the declarative macOS
  defaults, and declared tool versions -- plus itself, as a brew formula.

The kegs the migration had already poured are brew-compatible, so brew
simply adopts them -- no reinstall, and `brew bundle` no-ops on what is
present. The no-brew capability is not lost, just no longer the default: the
hand-rolled bridge (the `omlx-splash` task and the upgrade named-list) is in
the git history; if mise's shim gaps get fixed upstream and you want brew
gone, it is one restore plus deleting the Brewfiles. The two upstream gaps
(the metadata shim missing brew DSL, the source-build shim rejecting
`with_env`) are both bugs worth an issue against mise-dev/mise.

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
| `brew-bundle` | pre-packages (always) | runs `brew bundle` over `Brewfile` + `Brewfile.<host>`: installs what is missing, never upgrades (that is `up`'s job); on a failed entry it warns and continues so the dotfiles and agents still deploy -- re-run `brew bundle` in a terminal; no-op off macOS |
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
