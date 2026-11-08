# dotfiles

Three machines, configured by [mise](https://mise.jdx.dev) from this repo:

| Host | OS | What it is |
|---|---|---|
| `mca` | macOS | laptop |
| `gza` | macOS | desktop: always-on omlx and splash servers, omp host |
| `nwa` | NixOS | server |

This checkout *is* the global mise config: `~/.config/mise` is the repo.
Everything a machine needs -- packages, dotfiles, and the tasks bootstrap
runs -- lives here, so the git history is also the dotfile history. To
update a machine: edit, commit, push, run `mise bootstrap` there. To update
all of them at once, run `mise bootstrap remote` from any one of them.

The remote is `git@github.com:dolfth/dotfiles.git`. `main` is the mise era;
the older chezmoi setup lives under `archive/chezmoi`.

## Config layout

| File | Loads when | Holds |
|---|---|---|
| `mise.toml` | always | per-host fallback vars (accent/icon/tailnet/sshKeys), the shared dotfiles (incl. the omp agent config and aerospace), the syncthing LaunchAgent for both Macs, the bootstrap hooks, the fleet inventory (`[bootstrap.remote]`) |
| `mise.mac.toml` | `mac` selected | both Macs: the declarative macOS defaults, `$EDITOR`/`$VISUAL` (helix), `~/.zshrc`, `~/.ssh/config`, the fish functions, linearmouse |
| `mise.mca.toml` | `mca` selected | the laptop: host identity vars (host/accent/icon, HOST/KIND) |
| `mise.gza.toml` | `gza` selected | the desktop: the omlx and splash LaunchAgents, the omlx and pi configs; its brew entries are in `Brewfile.gza` |
| `mise.nwa.toml` | `nwa` selected | the pi and herdr configs (mise itself comes from Nix, not a package list) |
| `miserc.local.toml` | never committed | this machine's selection: `env = ["mac", "<host>"]` |
| `Brewfile`, `Brewfile.gza` | the brew-bundle task | the brew manifest: the shared entries, plus the desktop's servers |

The selection in `miserc.local.toml` decides which `mise.<env>.toml`
modules load. Everything else is environment-neutral.

One trap: mise reads `miserc.local.toml` only from `~/.config/mise/`. A
copy at `~/.config/miserc.local.toml`, one level up, is silently ignored.
The vars fall back to the base values and the host module's dotfiles never
deploy. This bit nwa in October 2026: its file sat one level too high, so
starship kept the base icon and the omp configs went stale.

## Bootstrap a Mac

```bash
xcode-select --install   # 1. Command Line Tools (a stub on a clean Mac); git and Homebrew reuse them
ssh-keygen -t ed25519 -a 100 -N "" -C gza -f ~/.ssh/id_ed25519   # 2. GitHub key; -C names the machine
pbcopy < ~/.ssh/id_ed25519.pub   # add under GitHub → Settings → SSH and GPG keys
ssh -T git@github.com
curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | bash   # 3. brew (needs sudo)
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile   # 3b. Apple silicon ships without brew on PATH
eval "$(/opt/homebrew/bin/brew shellenv)"
brew install mise   # 4. mise
mise bootstrap --adopt 'git@github.com:dolfth/dotfiles.git?ref=main' -E mac,gza   # 5. everything else
```

Step 5 clones the repo into `~/.config/mise` and runs the bootstrap. The
pre-packages hooks take the defaults snapshot and run `brew bundle` over
the Brewfiles. The dotfiles deploy, the launchd agents register, and the
final hooks run the system settings, the herdr and vscodium extensions, and
the Apple Intelligence removal.

Things that bite:

- The sudo part of system-check needs a TTY. Over ssh it is skipped; open a
  terminal and run `mise run system-check`.
- Apple Intelligence has one manual step: the task opens a profile in
  System Settings. Install it once per machine.
- `-E mac,gza` is written to `miserc.local.toml`, and every later mise
  command on the machine uses it. On the laptop use `-E mac,mca`. Without
  `-E`, the pre-packages hook writes `["mac"]` (the laptop defaults) and
  tells you to re-run; add the host name once the machine has a module.

Replacing a machine under the same hostname: take the old box off the
tailnet first -- power it off or have it leave -- *before* step 5. The
system-check hook sets the hostname and the agents register the services
under it, so two live `gza`s split MagicDNS and tailnet clients land on the
wrong machine. Once the old one is confirmed gone, swap the host key: the
new `~/.ssh/id_ed25519.pub` goes into `vars.ssh_keys` (`mise.toml`) and
onto `dolfth.keys`, and the old host's line comes out of both. Until its
key is listed, commits signed by the new key fail verification on the other
hosts.

Do not `chsh` to fish. `~/.zshrc` starts fish for interactive sessions, so
`$SHELL` stays POSIX for software that runs `$SHELL -c '...'`.

## Bootstrap nwa

The OS comes from nwa's NixOS flake (a separate repo). mise is a standalone
install in `~/.local/bin` -- the flake does not carry it -- and it reads
this checkout once the fleet-sync command below adopts it as
`~/.config/mise`. The first bootstrap deploys the omp, pi, and herdr
configs. After that nwa follows this repo like the Macs.

`mise.toml` sets a `min_version` floor (currently 2026.10.22). A mise below
the floor refuses every command with an upgrade hint. After a commit that
raises the floor, run `~/.local/bin/mise self-update` on nwa (or
`nix build .#mise` for the flake's copy) before bootstrapping again.

One gate: nwa runs Tailscale SSH. The first connection prints an approval
URL. Visit it once, then approve the key persistently in the Tailscale
admin console so unattended runs need no more URLs.

## Packages (the Brewfiles)

| What | Where |
|---|---|
| the formulae, casks, and App Store apps both Macs share | `Brewfile` |
| omlx + splash, desktop only | `Brewfile.gza` |

`brew bundle` (the brew-bundle task) installs what is missing and never
upgrades what is present; daily upgrades go through `up`. App Store entries
(`mas`) require being signed in, and the app in your purchase history.

### Why brew + mise (and not all-mise)

mise cannot install the desktop's omlx, splash, and omp. Its
formula-metadata shim doesn't implement the brew DSL their tap definitions
use, its source-build shim rejects omp's `with_env`, and resolution is
all-or-nothing per batch: one unresolvable formula fails the whole step. So
each ecosystem gets one owner:

- **brew** owns the brew ecosystem. The Brewfiles are the manifest,
  `brew bundle` installs, `up` upgrades. brew evaluates its own formulas
  natively, so all of them work as-is.
- **mise** owns everything else: dotfiles (merge and template support),
  tasks and bootstrap hooks, the launchd agents, the declarative macOS
  defaults, declared tool versions -- and itself, as a brew formula.

One tool fits neither: the Apple Intelligence removal, pared. There is no
mainline brew formula (the tap's is a source build that wants full Xcode)
and no mise backend, so the apple-intelligence task installs the pinned
GitHub release into `~/.local/share/pared`, checksum-verified.

brew adopts the kegs the mise era already poured; nothing gets reinstalled.
The all-mise fallback (a hand-rolled tap bridge) is in the git history. If
mise's shim gaps ever get fixed upstream, dropping brew means deleting the
Brewfiles and the task.

## Files (`[dotfiles]`)

| Source | Target | Notes |
|---|---|---|
| `zshrc` | `~/.zshrc` | both Macs; starts fish |
| `ssh_config` | `~/.ssh/config` | copied at 0600 -- a symlink would expose the repo file's permissions to ssh; key passphrases live in the Keychain |
| `fish/config.fish` | `~/.config/fish/config.fish` | all machines; the mise activation block |
| `fish/functions/*.fish` | `~/.config/fish/functions/` | Macs; nwa's home-manager owns its own functions. `up` upgrades everything, `mkd` makes and enters a directory, `tstat` lists the tailnet peers (the Tailscale app binary is the CLI -- the cask ships no `tailscale` command), `port` shows who holds a port |
| `starship.toml.tera` | `~/.config/starship.toml` | per-host accent and icon from the vars |
| `git/config` | `~/.config/git/config` | signs commits and tags with `~/.ssh/id_ed25519` |
| `git/allowed_signers.tera` | `~/.config/git/allowed_signers` | every host's public key (the `sshKeys` var) |
| `ghostty/config` | `~/.config/ghostty/config` | Nerd Font, so starship's glyphs render |
| `aerospace/aerospace.toml` | `~/.config/aerospace/aerospace.toml` | both Macs; merged -- AeroSpace rewrites the file itself when the layout changes in-app |
| `herdr/config.toml` | `~/.config/herdr/config.toml` | nwa only; copied -- herdr rewrites the file itself |
| `linearmouse.json` | `~/.config/linearmouse/linearmouse.json` | written only if absent, then LinearMouse owns it. "Start at Login" is a one-time UI toggle per machine -- it lives in the private login-items store; the system-check task reminds you |
| `pi/agent/settings.json` | `~/.pi/agent/settings.json` | gza + nwa; two pinned keys deep-merged into the file pi writes |
| `omlx/*.json` | `~/.omlx/` | gza; the pinned settings deep-merged into the files omlx writes (auth keys stay omlx's), plus server aliases for the host's `.local` and Tailscale names |
| `omp/agent/config.yml` | `~/.omp/agent/config.yml` | symlinked on every host: `/settings` changes flow back into the repo -- commit them |
| `omp/agent/models.yml.tera` | `~/.omp/agent/models.yml` | the omlx + splash providers; `baseUrl` is `127.0.0.1` on gza, the gza tailnet FQDN elsewhere |

Rows without a host apply to every machine. Files on disk that no loaded
module declares are left alone; `mise dot prune` removes ones the repo used
to track. To delete a file the repo deployed, declare it `mode = "absent"`
in the module that used to own it.

## Tasks and hooks (`mise-tasks/`)

| Task | Hook | Does |
|---|---|---|
| `defaults-snapshot` | pre-packages | hashes the defaults domains the UI reads, before bootstrap writes them |
| `brew-bundle` | pre-packages | `brew bundle` over `Brewfile` + `Brewfile.<host>`: installs what is missing, never upgrades (`up` does); a failed entry warns and continues -- re-run `brew bundle` in a terminal. No-op off macOS |
| `bootstrap` | the `bootstrap` task slot | for each `dev.mise.*` LaunchAgent: a guarded `launchctl bootstrap` (loads only a not-yet-loaded job) plus a bare `kickstart` (starts a dead agent, no-op on a healthy one -- never kills a running server); then reports who holds each port. No-op off gza |
| `herdr-plugins` | final | the herdr plugins the keybindings rely on; no-op where herdr is absent |
| `vscode-extensions` | final | the vscodium extensions; no-op where codium is absent |
| `system-check` | final | the macOS system settings: FDA-gated app defaults, hostname, firewall, the tailnet resolvers in resolv.conf, Touch ID, power, updates, the FileVault check, the GPU wired-limit daemon; the desktop also gets Screen Sharing and Remote Login. The sudo part needs a TTY. Dock/Finder/… restart only when a domain they read changed |
| `gpupool` | manual (gza) | the GPU pool is single-tenant -- pick its owner: `fn` flash-fn on :8100 (default), `27` the 27B splash server on :8000, `mlx` omlx on :8080 (it spawns its own engines on demand), `status` who answers. Two tenants would OOM-crash each other's Metal clients below the wired-limit fuse, so the rest stay unloaded |
| `apple-intelligence` | final | the Apple Intelligence removal via the pinned pared release: disables every feature in its catalog (Siri included), keeps the managed profile installed (one System Settings click per machine), removes downloaded models. Runs only on Apple-silicon macOS 27+ |

They run on every `mise bootstrap` / `mise update` and do nothing when
there is nothing to do. The pre-packages hook opens with a config gate:
`mise env` over the loaded config, failing the run when the config does not
parse or contains unknown fields. Normally an unknown key only warns and
keeps going, and mise 2026.10.x has no validate subcommand, so without the
gate a typo'd key would let the slow phases run on a half-wrong config.

## Desktop services (gza)

`omlx serve` (port 8080, binds `::`, API-key auth) and two splash servers
-- the 27B model on 8000, Flash-Next on 8100, both on `0.0.0.0` with
`--allowed-host` for the tailnet names -- run as user LaunchAgents in
`mise.gza.toml` (`dev.mise.*`, `ProcessType: Interactive`, unthrottled).
KeepAlive keeps them alive. Bootstrap reloads them when their definition
changes, the `bootstrap` task restarts a dead one on every run, and `up`
restarts a server whose keg was upgraded. Logs:
`~/Library/Logs/{omlx,splash,splash-fn}.log`.

All three bind beyond loopback on purpose: the other hosts' omp reaches
them over the tailnet. From 0.7.3 omlx enforces its API key on
non-loopback binds; the catalog in `omp/agent/models.yml.tera` carries the
key. The chat pages are at <http://127.0.0.1:8000> and
<http://127.0.0.1:8100>.

## Day to day

```bash
cd ~/.config/mise          # the repo; the mise config reads from here
mise bootstrap             # apply everything (hooks + packages + dotfiles)
mise dot status            # the file list; `mise dot diff` previews
git commit -am "…"; git push
```

Edit a template, preview with `mise dot diff`, re-render with
`mise dot apply`.

`mise bootstrap --update` (mise >= 2026.11.0) fast-forwards
`~/.config/mise` with `git pull --ff-only` and re-runs the whole bootstrap
from the new commit -- the local half of the fleet-sync two-step below. A
diverged checkout stops the run: `git pull` by hand, then re-run.

`mise bootstrap unapply` removes the dotfiles, packages, and services the
config declares (since mise 2026.9.13). Use it when a machine leaves the
fleet or a module is retired.

If `mise bootstrap` refuses to run the `bootstrap` task as "not trusted":
the machine's mise is new enough to gate task execution on config trust
(the 2026.10.19 release hardened it) and its checkout predates the
`trusted_config_paths` fix in `mise.toml`. `git pull` and re-run, or record
the checkout locally with `mise trust mise-tasks/bootstrap` (`mise trust
`~/.config/mise` normalizes to the already-trusted home and records
nothing).

## Fleet sync (`mise bootstrap remote`)

One command takes the whole fleet from this repo:

```bash
cd ~/.config/mise   # the repo; run it here
mise bootstrap remote --adopt 'git@github.com:dolfth/dotfiles.git?ref=main' --tag mac --update
mise bootstrap remote --adopt 'git@github.com:dolfth/dotfiles.git?ref=main' --host nwa --update --remote-mise /home/dolf/.local/bin/mise --force-dotfiles
```

It connects over SSH to every machine in the `[bootstrap.remote.hosts]`
inventory (`mise.toml`) and, on each one, adopts this checkout as its
`~/.config/mise` (an existing checkout is reused as-is; `--update`
fast-forwards it first -- without it, a host behind main re-applies its
stale commit), stages the orchestrator's mise so the run parses with one
version, and runs the full `mise bootstrap` there: hooks, packages,
dotfiles, services. Each host keeps its own mise install and its running
services. A host that fails is reported at the end while the others
proceed.

Any machine can orchestrate. gza is the default because it is always on
and reachable; mca, the laptop, is reachable only while awake on the
tailnet. `--tag mac` targets just the Macs, `--tag nix` just nwa.

Four things to know:

- The remote run loads each host's own `miserc.local.toml` -- the same file
  local runs use, so there is one selection per machine and nothing to keep
  in sync. A brand-new host has none at all: pass `--remote-env mac` on the
  one-time onboarding command (mise >= 2026.10.22 has the flag).
- nwa runs Tailscale SSH: the first connection prints a one-off approval
  URL. Visit it, then approve the key persistently in the admin console.
- nwa is cross-platform and the orchestrator's mise is a Homebrew build.
  Mise will not substitute an official release binary for a non-official
  local one, so nwa runs under its own mise (`remote_mise` in the
  inventory). Orchestrators through 2026.10.19 ignore that config field,
  and a command-line `--remote-mise` applies to every selected host (the
  Macs have no such path) -- hence the separate nwa command above. When an
  orchestrator honors the field, the two commands merge back into one
  `--all`.
- The nwa command passes `--force-dotfiles` because the apps on nwa rewrite
  their deployed configs themselves (herdr's is a copy, not a symlink),
  and the dotfiles apply refuses to overwrite a whole-file entry that has
  drifted -- that aborts the whole phase. The flag resets them to the repo
  version. The Macs need nothing: their omp config is a symlink into the
  repo (a local write is a checkout edit that gets committed) and the pi
  entry merges.

A brand-new machine lays its OS floor first -- a Mac: the steps above; a
NixOS box: its flake, plus a standalone mise install (the flake does not
carry one, so give the host `remote_mise` in the inventory). Then this,
from anywhere, with no session on the box:

```bash
mise bootstrap remote --adopt '…' --host newbox.ts.net --remote-env mac
```

`--remote-env` is the one-time env selection; the box has no miserc yet,
and the remote run loads each host's own file otherwise. On a Mac, that
bootstrap also writes the box's missing `miserc.local.toml` (`["mac"]` plus
a nudge to add its host module) for the box's later local runs.
