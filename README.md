# dotfiles

Two Macs, configured by [mise](https://mise.jdx.dev) from this repo:

| Host | OS | What it is |
|---|---|---|
| `mca` | macOS | laptop |
| `gza` | macOS | desktop: always-on llama-swap front for the two splash pool models (omlx installed, out of pool), omp host |

nwa, the NixOS server, is not configured from this repo: its flake owns
the whole machine. gza monitors and maintains it: the `nwa-health` job
probes it over Tailscale SSH, and its flake gets edits over ssh through
the `nwa-omp` entry point.

The checkout *is* the global mise config: `~/.config/mise` is this repo.
Packages, dotfiles, and the tasks bootstrap runs all live here, so the git
history is the dotfile history.

- Update one machine: edit, commit, push, run `mise bootstrap` there.
- Update every machine: `mise bootstrap remote` from any one of them.
- Add a machine: follow the bootstrap below.

Remote: `git@github.com:dolfth/dotfiles.git`, branch `main`.

Reference: [files](notes/dotfiles.md) · [tasks](notes/tasks.md) ·
[sandbox](notes/sandbox.md) · [services](notes/services.md) ·
[pitfalls](notes/pitfalls.md)

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
agents, the system settings, the vscodium extensions, and, on gza, the
herdr extensions and the omp sandbox. Then the Apple Intelligence
removal.

Three things need a terminal at the machine afterwards (ssh is skipped
for the first):

- `mise run dev-agents && mise run system-check` -- their sudo parts need a TTY. `dev-agents` skips off gza.
- The Apple Intelligence task opens a profile in System Settings; click
  Install. One manual click per machine.
- Tick "Start at Login" in LinearMouse -- a UI-only toggle; the system
  check reminds while it is unticked.

The traps worth knowing before you debug a half-configured box (env
selection, cwd sensitivity, the version floor, machine replacement):
[notes/pitfalls.md](notes/pitfalls.md).

## SSH between hosts

The mac module renders the `sshKeys` var to `~/.ssh/authorized_keys` on
both Macs, so any fleet machine can `ssh <host>.<tailnet>` without a
password. The var is the list at <https://github.com/dolfth.keys>; to
retire a machine, drop its key from both and bootstrap. Keys added by
hand on a host do not survive the next bootstrap.

nwa is not bootstrapped from here, but connecting to it has a quirk:
it runs Tailscale SSH, whose first connection from a new key prints an
approval URL -- approve the key persistently in the Tailscale admin
console, or every unattended probe (the `nwa-health` agent) waits on a
browser. Its flake owns authorized_keys. The Macs stay on the Tailscale
app variant: it cannot serve Tailscale SSH (variant matrix), and keys
cover the paths where that would matter, LAN included. gza keeps
password auth for one
case only: the pre-unlock FileVault login window
(`man apple_ssh_and_filevault`) takes a password, no keys -- after a
power cut that is the way back in. Keep the Tailscale app current: the
TS-2026-014..017 fixes are in 1.104.4.

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

## Fleet sync (`mise bootstrap remote`)

One command takes the whole fleet from this repo:

```bash
cd ~/.config/mise   # the repo; run it here
mise bootstrap remote --adopt 'git@github.com:dolfth/dotfiles.git?ref=main' --tag mac --update
```

It connects over SSH to every machine in the `[bootstrap.remote.hosts]`
inventory (`mise.toml`) and, on each one, adopts this checkout as its
`~/.config/mise` (`--update` fast-forwards an existing checkout so a
host behind `main` does not re-apply its stale commit), then runs the
full `mise bootstrap` there: hooks, packages, dotfiles, services. A host
that fails is reported at the end while the others proceed.

Any machine can orchestrate. gza is the default because it is always on
and reachable; mca only while awake on the tailnet. `--tag mac` targets
both Macs.

- The remote run loads each host's own `miserc.local.toml` -- the same
  file local runs use, so there is one selection per machine. A
  brand-new host has none: pass `--remote-env mac` on the one-time
  onboarding command; on a Mac the bootstrap then writes `["mac"]`
  plus a nudge to add the host module, for the box's later local runs.
- The Macs need no `--force-dotfiles`: their rewriting configs are
  symlinked or merged, and the omp config that would drift lives on
  gza alone.

A brand-new machine lays its OS floor first -- the Mac steps above.
Then, from anywhere, with no session on
the box:

```bash
mise bootstrap remote --adopt '…' --host newbox.ts.net --remote-env mac
```

## Config layout

| File | Loads when | Holds |
|---|---|---|
| `mise.toml` | always | per-host fallback vars (accent/icon/tailnet/sshKeys), the shared dotfiles (incl. the aerospace merge), the syncthing LaunchAgent for both Macs, the bootstrap hooks, the fleet inventory (`[bootstrap.remote]`) |
| `mise.mac.toml` | `mac` selected | both Macs: the declarative macOS defaults, the pin table (`[vars]`: omp, pared, LuxMini -- version + sha256, consumed by the fetching tasks and pin-check), `$EDITOR`/`$VISUAL` (helix), `~/.zshenv`, `~/.zshrc`, `~/.ssh/config`, the fish functions, linearmouse |
| `mise.mca.toml` | `mca` selected | the laptop: host identity vars (host/accent/icon, HOST/KIND) |
| `mise.gza.toml` | `gza` selected | the desktop: the llama-swap and omlx LaunchAgents, the omp, omlx, pi and herdr configs, the llama-swap front door's config; its brew entries, the agent stack included, are in `Brewfile.gza` |
| `miserc.local.toml` | never committed | this machine's selection: `env = ["mac", "<host>"]` |
| `Brewfile`, `Brewfile.gza` | the brew-bundle task | the brew manifest: the shared entries, plus the desktop's servers and agent stack |
| `notes/` | never loaded | the reference: files and their merge/copy rationale, the task table, the sandbox installs, the GPU-pool services, the pitfalls |

The selection in `miserc.local.toml` decides which `mise.<env>.toml`
modules load. Everything else is environment-neutral.

## Packages (the Brewfiles)

| What | Where |
|---|---|
| the formulae, casks, and App Store apps both Macs share | `Brewfile` |
| omlx + splash + llama-swap, desktop only | `Brewfile.gza` |

`brew bundle` (the brew-bundle task) installs what is missing and never
upgrades what is present; daily upgrades go through `up`. App Store
entries (`mas`) require the machine to be signed in to the App Store,
and the app in the account's purchase history -- otherwise they fail and
the task reports the missing IDs.

Why brew owns the brew ecosystem: mise cannot install omlx, splash,
llama-swap and omp (its formula shim lacks their taps' brew DSL, and resolution is
all-or-nothing per batch), while brew evaluates its own formulas
natively. Everything else is mise's: dotfiles, tasks and hooks, launchd
agents, the declarative macOS defaults, declared tool versions -- and
mise itself, as a brew formula. One exception fits neither ecosystem:
pared, the Apple Intelligence removal, has no formula and no mise
backend, so its task installs the pinned, checksum-verified GitHub
release itself.

## Files (`[dotfiles]`)

Every declared file, its target, and the per-file reasoning (why a copy
where a symlink would leak the repo's permissions, why a merge where an
app rewrites its own config): [notes/dotfiles.md](notes/dotfiles.md).
The gza omp sandbox installs -- profiles, wrappers, agent notes -- are in
[notes/sandbox.md](notes/sandbox.md).

## Tasks and hooks (`mise-tasks/`)

The full task table -- hook slots, what each task does, the heartbeat and
sandbox contracts: [notes/tasks.md](notes/tasks.md).

They run on every `mise bootstrap` (plain, or with `--update` to refresh
metadata and repositories first — `mise upgrade`, the `up` function, is tool
upgrades, not an apply) and do nothing when
there is nothing to do. The macOS-only tasks carry the `macos` tag and
the gza agent jobs carry `gza` (mise >= 2026.11.2), so a group can be selected
explicitly -- `mise run --tag macos`, `mise tasks ls --tag gza` -- instead
of relying on the uname guards. `--output summary` collapses a multi-task
run to one line per pass; with `task.logs = true` (mise >= 2026.11.3) a
failed task's full output is kept for `mise tasks log NAME`. The
pre-packages hook opens with a config gate:
`mise env` over the loaded config, failing the run when the config does
not parse or contains unknown fields -- normally a typo'd key only warns,
and the slow phases would then run on a half-wrong config.

## Desktop services (gza)

The GPU pool and its llama-swap front door -- the single-tenant rule,
the key, the logs -- and the scheduled omp agent jobs:
[notes/services.md](notes/services.md).
