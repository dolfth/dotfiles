# dotfiles

Three machines, configured by [mise](https://mise.jdx.dev) from this repo:

| Host | OS | What it is |
|---|---|---|
| `mca` | macOS | laptop |
| `gza` | macOS | desktop: always-on omlx and splash servers, omp host |
| `nwa` | NixOS | server |

The checkout *is* the global mise config: `~/.config/mise` is this repo.
Packages, dotfiles, and the tasks bootstrap runs all live here, so the git
history is the dotfile history.

- Update one machine: edit, commit, push, run `mise bootstrap` there.
- Update every machine: `mise bootstrap remote` from any one of them.
- Add a machine: follow the bootstrap below.

Remote: `git@github.com:dolfth/dotfiles.git`, branch `main`.

## Bootstrap a Mac

**Sign in to the App Store first.** The Brewfile's App Store entries
(`mas`) cannot download until the machine is signed in, and an app must
already be in its purchase history; a bootstrap without a sign-in warns
with the missing app IDs instead of installing them.

```bash
xcode-select --install                                        # 1. Command Line Tools (git and Homebrew need them)
ssh-keygen -t ed25519 -a 100 -N "" -C gza -f ~/.ssh/id_ed25519   # 2. GitHub key; -C names the machine
pbcopy < ~/.ssh/id_ed25519.pub                                #    add under GitHub → Settings → SSH and GPG keys
ssh -T git@github.com                                         #    must answer "Hi dolfth!"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"   # 3. Homebrew (official installer; needs sudo)
# 3b. run the installer's own "Next steps" -- on Apple silicon they put
#     brew on PATH via ~/.zprofile; do them before continuing.
brew install mise                                             # 4. mise
mise bootstrap --adopt 'git@github.com:dolfth/dotfiles.git?ref=main' -E mac,gza   # 5. everything else; laptop: -E mac,mca
```

Step 5 clones the repo into `~/.config/mise` and runs the bootstrap:
packages (`brew bundle` over the Brewfiles), dotfiles, the launchd
agents, the system settings, the herdr and vscodium extensions, and the
Apple Intelligence removal.

Three things need a terminal at the machine afterwards (ssh is skipped
for the first):

- `mise run system-check` -- its sudo part needs a TTY.
- The Apple Intelligence task opens a profile in System Settings; click
  Install. One manual click per machine.
- Tick "Start at Login" in LinearMouse -- a UI-only toggle; the system
  check reminds while it is unticked.

Pitfalls:

- `-E mac,gza` is written to `miserc.local.toml` and every later mise
  command on the machine uses it. Without `-E` the hook writes
  `["mac"]` (the laptop defaults) and tells you to re-run with the host
  name added.
- mise reads `miserc.local.toml` only from `~/.config/mise/`. A copy one
  level up is silently ignored: the vars fall back to the base values and
  the host module's dotfiles never deploy.
- A mise below the `min_version` floor in `mise.toml` refuses every
  command with an upgrade hint. `brew upgrade mise` and re-run.
- Do not `chsh` to fish. `~/.zshrc` starts fish for interactive sessions,
  so `$SHELL` stays POSIX for software that runs `$SHELL -c '...'`.

Replacing a machine under the same hostname: take the old box off the
tailnet first -- power it off or have it leave -- *before* step 5. The
system-check hook sets the hostname and the agents register under it, so
two live `gza`s split MagicDNS. Then swap the host key: the new
`~/.ssh/id_ed25519.pub` goes into `vars.ssh_keys` (`mise.toml`) and onto
<https://github.com/dolfth.keys>, and the old key comes out of both.
Commits signed by an unlisted key fail verification on the other hosts.

## Bootstrap nwa

The OS comes from nwa's NixOS flake (a separate repo). mise is a
standalone install in `~/.local/bin` -- the flake does not carry it --
and it reads this checkout once a bootstrap adopts it as
`~/.config/mise`. The first bootstrap deploys the omp, pi, and herdr
configs; after that nwa follows this repo like the Macs.

Two gates:

- nwa runs Tailscale SSH. The first connection prints an approval URL;
  visit it once, then approve the key persistently in the Tailscale
  admin console so unattended runs need no more URLs.
- After a commit that raises the `min_version` floor, run
  `~/.local/bin/mise self-update` (or `nix build .#mise` for the flake's
  copy) before bootstrapping again.

## Day to day

```bash
cd ~/.config/mise          # the repo; the mise config reads from here
mise bootstrap             # apply everything (hooks + packages + dotfiles)
mise dot status            # the file list; `mise dot diff` previews changes
git commit -am "…"; git push
```

Edit a template: preview with `mise dot diff`, re-render with
`mise dot apply`. To audit coverage, `mise dot files <path>` (mise >=
2026.11.5) shows per-file state -- `tracked`/`excluded`/`omitted`/
`untracked`/`partial` -- and names the rule behind each.

`mise bootstrap --update` (mise >= 2026.11.0) fast-forwards
`~/.config/mise` with `git pull --ff-only` and re-runs the whole
bootstrap from the new commit. A diverged checkout stops the run: pull
by hand, then re-run.

`mise bootstrap unapply` removes the dotfiles, packages, and services
the config declares. Use it when a machine leaves the fleet or a module
is retired.

If `mise bootstrap` refuses to run the `bootstrap` task as "not
trusted": the checkout predates the `trusted_config_paths` entry in
`mise.toml`. `git pull` and re-run, or record the checkout locally with
`mise trust mise-tasks/bootstrap` (plain `mise trust ~/.config/mise`
normalizes to the already-trusted home and records nothing).

## Fleet sync (`mise bootstrap remote`)

One command takes the whole fleet from this repo:

```bash
cd ~/.config/mise   # the repo; run it here
mise bootstrap remote --adopt 'git@github.com:dolfth/dotfiles.git?ref=main' --tag mac --update
mise bootstrap remote --adopt 'git@github.com:dolfth/dotfiles.git?ref=main' --host nwa --update --remote-mise /home/dolf/.local/bin/mise --force-dotfiles
```

It connects over SSH to every machine in the `[bootstrap.remote.hosts]`
inventory (`mise.toml`) and, on each one, adopts this checkout as its
`~/.config/mise` (`--update` fast-forwards an existing checkout so a
host behind `main` does not re-apply its stale commit), then runs the
full `mise bootstrap` there: hooks, packages, dotfiles, services. A host
that fails is reported at the end while the others proceed.

Any machine can orchestrate. gza is the default because it is always on
and reachable; mca only while awake on the tailnet. `--tag mac` targets
just the Macs, `--tag nix` just nwa.

- The remote run loads each host's own `miserc.local.toml` -- the same
  file local runs use, so there is one selection per machine. A
  brand-new host has none: pass `--remote-env mac` on the one-time
  onboarding command; on a Mac the bootstrap then writes `["mac"]`
  plus a nudge to add the host module, for the box's later local runs.
- nwa is cross-platform and the orchestrator's mise is a Homebrew build;
  mise will not substitute an official release binary for a non-official
  local one, so nwa runs under its own mise (`remote_mise` in the
  inventory).
- The nwa command passes `--force-dotfiles` because the apps on nwa
  rewrite their deployed configs (herdr's is a copy, not a symlink) and
  the dotfiles apply aborts on drift. The Macs need nothing: their omp
  config is a symlink into the repo and the pi entry merges.

A brand-new machine lays its OS floor first -- a Mac: the steps above; a
NixOS box: its flake plus a standalone mise install (give the host
`remote_mise` in the inventory). Then, from anywhere, with no session on
the box:

```bash
mise bootstrap remote --adopt '…' --host newbox.ts.net --remote-env mac
```

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

## Packages (the Brewfiles)

| What | Where |
|---|---|
| the formulae, casks, and App Store apps both Macs share | `Brewfile` |
| omlx + splash, desktop only | `Brewfile.gza` |

`brew bundle` (the brew-bundle task) installs what is missing and never
upgrades what is present; daily upgrades go through `up`. App Store
entries (`mas`) require the machine to be signed in to the App Store,
and the app in the account's purchase history -- otherwise they fail and
the task reports the missing IDs.

Why brew owns the brew ecosystem: mise cannot install omlx, splash, and
omp (its formula shim lacks their taps' brew DSL, and resolution is
all-or-nothing per batch), while brew evaluates its own formulas
natively. Everything else is mise's: dotfiles, tasks and hooks, launchd
agents, the declarative macOS defaults, declared tool versions -- and
mise itself, as a brew formula. One exception fits neither ecosystem:
pared, the Apple Intelligence removal, has no formula and no mise
backend, so its task installs the pinned, checksum-verified GitHub
release itself.

## Files (`[dotfiles]`)

| Source | Target | Notes |
|---|---|---|
| `zshrc` | `~/.zshrc` | both Macs; starts fish |
| `ssh_config` | `~/.ssh/config` | copied at 0600 -- a symlink would expose the repo file's permissions to ssh; key passphrases live in the Keychain |
| `fish/config.fish` | `~/.config/fish/config.fish` | all machines; the mise activation block |
| `fish/functions/*.fish` | `~/.config/fish/functions/` | Macs; nwa's home-manager owns its own functions. `up` upgrades everything, `mkd` makes and enters a directory, `tstat` lists the tailnet peers, `port` shows who holds a port |
| `starship.toml.tera` | `~/.config/starship.toml` | per-host accent and icon from the vars |
| `git/config` | `~/.config/git/config` | signs commits and tags with `~/.ssh/id_ed25519` |
| `git/allowed_signers.tera` | `~/.config/git/allowed_signers` | every host's public key (the `sshKeys` var) |
| `ghostty/config` | `~/.config/ghostty/config` | Nerd Font, so starship's glyphs render |
| `aerospace/aerospace.toml` | `~/.config/aerospace/aerospace.toml` | both Macs; merged -- AeroSpace rewrites the file itself when the layout changes in-app |
| `herdr/config.toml` | `~/.config/herdr/config.toml` | nwa only; copied -- herdr rewrites the file itself |
| `linearmouse.json` | `~/.config/linearmouse/linearmouse.json` | written only if absent, then LinearMouse owns it |
| `pi/agent/settings.json` | `~/.pi/agent/settings.json` | gza + nwa; two pinned keys deep-merged into the file pi writes |
| `omlx/*.json` | `~/.omlx/` | gza; the pinned settings deep-merged into the files omlx writes (auth keys stay omlx's), plus server aliases for the host's `.local` and Tailscale names |
| `omp/agent/config.yml` | `~/.omp/agent/config.yml` | symlinked on every host: `/settings` changes flow back into the repo -- commit them |
| `omp/agent/models.yml.tera` | `~/.omp/agent/models.yml` | the omlx + splash providers; `baseUrl` is `127.0.0.1` on gza, the gza tailnet FQDN elsewhere |

Rows without a host apply to every machine. Files on disk that no loaded
module declares are left alone; `mise dot prune` removes ones the repo
used to track. To delete a file the repo deployed, declare it
`mode = "absent"` in the module that used to own it.

## Tasks and hooks (`mise-tasks/`)

| Task | Hook | Does |
|---|---|---|
| `defaults-snapshot` | pre-packages | hashes the defaults domains the UI reads, before bootstrap writes them |
| `brew-bundle` | pre-packages | `brew bundle` over `Brewfile` + `Brewfile.<host>`: installs what is missing, never upgrades (`up` does); a failed entry warns and continues -- re-run `brew bundle` in a terminal. No-op off macOS |
| `bootstrap` | the `bootstrap` task slot | for each `dev.mise.*` LaunchAgent: a guarded `launchctl bootstrap` (loads only a not-yet-loaded job) plus a bare `kickstart` (starts a dead agent, no-op on a healthy one -- never kills a running server); then reports who holds each port. No-op off gza |
| `herdr-plugins` | final | the herdr plugins the keybindings rely on; no-op where herdr is absent |
| `vscode-extensions` | final | the vscodium extensions; no-op where codium is absent |
| `system-check` | final | the macOS system settings: FDA-gated app defaults, hostname, firewall, the tailnet resolvers in resolv.conf, Touch ID, power, updates, the FileVault check, the GPU wired-limit daemon; the desktop also gets Screen Sharing and Remote Login. The sudo part needs a TTY. Dock/Finder/… restart only when a domain they read changed |
| `apple-intelligence` | final | the Apple Intelligence removal via the pinned pared release: disables every feature in its catalog (Siri included), keeps the managed profile installed (one System Settings click per machine), removes downloaded models. Runs only on Apple-silicon macOS 27+ |
| `finder-favorites` | final | Finder sidebar Favorites = every visible `$HOME` directory plus what is already pinned, alphabetically. Favorites are an LSSharedFileList archive, not a defaults domain, so the task writes through that (deprecated, alive) API; Finder updates live and a converged list is a no-op. No-op off macOS |
| `gpupool` | manual (gza) | the GPU pool is single-tenant -- pick its owner: `fn` flash-fn on :8100 (default), `27` the 27B splash server on :8000, `mlx` omlx on :8080, `status` who answers. Two tenants would OOM-crash each other's Metal clients, so the rest stay unloaded |

They run on every `mise bootstrap` / `mise update` and do nothing when
there is nothing to do. The macOS-only tasks carry the `macos` tag and
`gpupool` carries `gza` (mise >= 2026.11.2), so a group can be selected
explicitly -- `mise run --tag macos`, `mise tasks ls --tag gza` -- instead
of relying on the uname guards. `--output summary` collapses a multi-task
run to one line per pass; with `task.logs = true` (mise >= 2026.11.3) a
failed task's full output is kept for `mise tasks log NAME`. The
pre-packages hook opens with a config gate:
`mise env` over the loaded config, failing the run when the config does
not parse or contains unknown fields -- normally a typo'd key only warns,
and the slow phases would then run on a half-wrong config.

## Desktop services (gza)

`omlx serve` (port 8080) and two splash servers -- the 27B model on
8000, Flash-Next on 8100 -- run as user LaunchAgents declared in
`mise.gza.toml`. The GPU wired pool (the 96 GiB fuse system-check
installs) is **single-tenant**: below the fuse the kernel refuses
nothing, so two resident servers OOM-crash each other's Metal clients
instead of queueing. Only flash-fn (the default owner) is RunAtLoad; the
27B and omlx start only when `mise run gpupool fn|27|mlx` swaps them in
-- which is also why their `RunAtLoad`/`KeepAlive`/`kickstart` stay off:
a launchd apply starts any agent with `kickstart = true`, however idle.

Bootstrap rewrites plists when definitions change, the `bootstrap` task
restarts a dead flash-fn on every run, and `up` restarts a server whose
keg was upgraded. Logs: `~/Library/Logs/{omlx,splash,splash-fn}.log`.

All three bind beyond loopback on purpose: the other hosts' omp reaches
them over the tailnet; omlx enforces its API key on non-loopback binds,
and the catalog (`omp/agent/models.yml.tera`) carries the key. The chat
pages are at <http://127.0.0.1:8000> and <http://127.0.0.1:8100>.
