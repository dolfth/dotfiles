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
`git commit`, push; then `mise bootstrap remote` takes the fleet (see
below). The remote is
`git@github.com:dolfth/dotfiles.git` -- `main` is the mise era, the pre-mise
chezmoi iteration lives on under `archive/chezmoi`.

## Config layout

| File | Loads when | Holds |
|---|---|---|
| `mise.toml` | always | per-host data in `[vars]` (accent/icon/tailnet/sshKeys), the shared dotfiles, the bootstrap hooks, the fleet inventory (`[bootstrap.remote]`) |
| `mise.mac.toml` | `mac` selected | both Macs: the declarative macOS defaults, `$EDITOR`/`$VISUAL` (helix), `~/.zshrc`, `~/.ssh/config`, `up.fish`, linearmouse |
| `mise.mca.toml` | `mca` selected | the laptop: the syncthing user service (its GUI software lives in `Brewfile.mca`) |
| `mise.gza.toml` | `gza` selected | the desktop: the omlx + splash LaunchAgents, the agent self-heal, the omlx, omp and pi configs (its formulae live in `Brewfile.gza`) |
| `mise.nwa.toml` | `nwa` selected | the omp, pi and herdr configs (mise on nwa comes from Nix, not a package list) |
| `miserc.local.toml` | not committed | this machine: `env = ["mac", "<host>"]` |
| `Brewfile`, `Brewfile.mca`, `Brewfile.gza` | the brew-bundle task (Macs) | the brew-ecosystem manifest per machine (see below) |

Selecting the environments in `miserc.local.toml` loads the module files
(`mise.<env>.toml`); everything else in the config is environment-neutral.
Mise reads that file only from the mise config directory
(`~/.config/mise/`): a copy one level up, at `~/.config/miserc.local.toml`,
is silently ignored -- the vars fall back to the base values and the host
module's dotfiles never deploy (this bit nwa in 2026.10: its file sat there,
so starship kept the base icon and the omp configs went stale).

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
skipped without a terminal -- re-run `mise run system-check` in one), the
herdr and vscodium extensions, and the Apple Intelligence removal (its one
manual bit: install the profile it opens in System Settings, once per
machine).

The `-E mac,gza` lands in `~/.config/mise/miserc.local.toml`, and every later
mise command on the machine uses it (select `-E mac,mca` on the laptop).
Without `-E`, the pre-packages hook writes the `["mac"]` fallback itself (the
laptop defaults) and says to re-run; add the host module when the machine
gets one.

Do **not** `chsh` to fish: `~/.zshrc` starts fish for interactive sessions,
so `$SHELL` stays POSIX for software that runs `$SHELL -c '...'`.

## Bootstrap nwa

The OS comes from nwa's NixOS flake (its own repo). mise is a standalone
install in `~/.local/bin` -- the flake does not carry it -- and it reads this
checkout once the fleet-sync command below adopts it as `~/.config/mise`;
the first bootstrap deploys the omp, pi, and herdr configs. After that, nwa
follows this repo like the Macs.

One gate: nwa runs Tailscale SSH. The first connection prints a one-off
approval URL -- visit it once, then approve the key persistently in the
Tailscale admin console so unattended fleet runs need no more URLs.

## Layout

### Packages (the Brewfiles)

| What | Where |
|---|---|
| 14 formulae (incl. mise) + 3 casks, both Macs | `Brewfile` |
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

One tool is neither: the Apple Intelligence removal (pared) has no mainline
brew formula (the tap's is a source build wanting full Xcode) and no mise
backend, so the apple-intelligence task installs the pinned GitHub release
into `~/.local/share/pared` (the task explains the mechanism).

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
| `herdr-plugins` | final | the herdr plugins the keybindings rely on; no-op where herdr is absent |
| `vscode-extensions` | final | the vscodium extensions; no-op where codium is absent |
| `system-check` | final | the macOS system settings: FDA-gated app defaults, hostname, firewall, Touch ID, power, updates, FileVault check, the GPU wired-limit daemon; the desktop gets Screen Sharing + Remote Login. The sudo part is TTY-gated. Restarts Dock/Finder/… only when a domain they read changed |
| `apple-intelligence` | final | the Apple Intelligence removal via the pinned pared release (checksum-verified into `~/.local/share/pared`): disables every feature in its catalog (Siri included), keeps the managed profile installed (one System Settings click per machine), removes downloaded models. No-op off Apple-silicon macOS 27+ |

They run on every `mise bootstrap` / `mise update` and no-op when there is
nothing to do. The pre-packages hook opens with a config gate -- `mise env`
over the loaded config, failing the run on a config that does not parse or
on unknown fields (a typo'd key only warns and is ignored, and mise
2026.10.x has no validate subcommand) -- so a typo dies in a second.

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

If `mise bootstrap` refuses to run the `bootstrap` task as "not trusted",
the machine's mise is new enough to gate task execution on config trust
(the 2026.10.19 release hardened it) and its checkout predates the
`trusted_config_paths` fix in `mise.toml`: `git pull` and re-run, or record
the checkout locally with `mise trust mise-tasks/bootstrap` (a path into the
checkout; `mise trust ~/.config/mise` normalizes to the already-trusted home
and records nothing).

## Fleet sync (`mise bootstrap remote`)

One command takes the whole fleet from this repo:

```bash
cd ~/.config/mise   # the repo; run it here
mise bootstrap remote --adopt 'git@github.com:dolfth/dotfiles.git?ref=main' --tag mac --update
mise bootstrap remote --adopt 'git@github.com:dolfth/dotfiles.git?ref=main' --host nwa --update --remote-mise /home/dolf/.local/bin/mise --force-dotfiles
```

It connects to every machine in the `[bootstrap.remote.hosts]` inventory
(`mise.toml`) over SSH and, on each, adopts this checkout as its
`~/.config/mise` (an existing checkout is reused as-is; `--update`
fast-forwards it first, and without it a host behind main re-applies its
stale commit), stages the orchestrator's mise so the run parses with one
version (except nwa, which runs under its own mise -- see the notes),
and
runs the full `mise bootstrap` there -- hooks, packages, dotfiles,
services, all of it. A host's own mise install and its running services
are left alone; a host that fails is reported at the end while the others
proceed.

Any machine can orchestrate; gza is the default because it is always on
and reachable, while mca (the laptop) is reachable only while awake on
the tailnet. `--tag mac` targets just the Macs, `--tag nix` just nwa.

Four notes:

- The inventory's `mise_env` is authoritative for the remote run: it
  replaces the host's own `miserc.local.toml` selection (a brand-new
  machine has none at all), so keep it in sync with each machine's local
  file.
- nwa runs Tailscale SSH: the first connection prints a one-off approval
  URL -- visit it, then persistently approve the key in the Tailscale
  admin console so unattended runs work.
- nwa is cross-platform and the orchestrator's mise is a Homebrew build:
  mise will not substitute an official release binary for a non-official
  local one, so nwa runs under its own mise (`remote_mise` in the
  inventory); the nwa command above passes it on the command line, because
  orchestrators through 2026.10.19 ignore the config field and a
  command-line `--remote-mise` applies to every selected host (the Macs
  have no such path). When an orchestrator honors the field, the two
  commands merge back into one `--all`.
- The nwa command passes `--force-dotfiles`: the apps on nwa rewrite their
  deployed configs themselves (herdr's is a copy, not a symlink), and the
  dotfiles apply refuses to overwrite a whole-file entry that has drifted
  from its source, aborting the whole phase. The flag resets them to the
  repo version. The Macs need none: their omp config is a symlink into the
  repo (a local write is a checkout edit that gets committed) and the pi
  entry merges.

A brand-new machine lays its OS floor first (a Mac: the steps above; a
NixOS box: its flake, plus a standalone mise install -- the flake does not
carry one, so give the host `remote_mise` in the inventory) -- then
`mise bootstrap remote --adopt '…' --host newbox.ts.net` does the rest
from anywhere, no session on the box needed.
On a Mac, that bootstrap also writes the box's missing `miserc.local.toml`
(`["mac"]` + a nudge to add its host module) for the box's later local runs;
the remote run itself follows the inventory's `mise_env` (above).
