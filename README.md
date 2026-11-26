# dotfiles

Two Macs, configured by [mise](https://mise.jdx.dev) from this repo:

| Host | OS | What it is |
|---|---|---|
| `mca` | macOS | laptop |
| `gza` | macOS | desktop: for dev and local ai |

This repo is checked out as `~/.config/mise`, which is where mise reads
its global config.

- Update one machine: edit, commit, push, run `mise bootstrap` there.
- Update every machine: `mise bootstrap remote` from any one of them.
- Add a machine: follow the bootstrap below.

## Bootstrap a Mac

**Sign in to the App Store first.** The Brewfile's App Store entries
(`mas`) cannot download until the machine is signed in. An App Store app
must also already be in the purchase history.

```bash
# 1. Install Command Line Tools for git and Homebrew
xcode-select --install

# 2. Create GitHub key with -C for the machine name
ssh-keygen -t ed25519 -a 100 -N "" -C gza -f ~/.ssh/id_ed25519

# 3. Paste the key under GitHub → Settings → SSH and GPG keys
pbcopy < ~/.ssh/id_ed25519.pub

# 4. Check if the key is working
ssh -T git@github.com

# 5. Install Homebrew from the official installer and run the
#    installer's "Next steps"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 6. Install mise
brew install mise

# 7. Bootstrap the machine; -E names the environment, the machine
#    name, so mise loads mise.<ENV>.toml; --save-env records the
#    selection in miserc.local.toml
mise bootstrap --adopt 'git@github.com:dolfth/dotfiles.git?ref=main' -E gza --save-env
```

The last step clones the repo into `~/.config/mise` and runs the
bootstrap: packages (`brew bundle` over the Brewfiles), dotfiles, the
system settings, the launchd agents, the vscodium extensions, and, on
gza, the herdr extensions and the omp sandbox. Finally the Apple
Intelligence removal on both.

Three things need a user present at the Mac:

- `mise run dev-agents && mise run system-check`; the sudo parts need a
  TTY. `dev-agents` skips off gza.
- The Apple Intelligence task opens a profile in System Settings; needs
  a manual click on "Install".
- Tick "Start at Login" in LinearMouse -- a UI-only toggle; the system
  check reminds while it is unticked.

The traps worth knowing before you debug a half-configured box (env
selection, the version floor, machine replacement):
the Pitfalls section at the end.

## SSH between hosts

The main module renders the `ssh_keys` var to `~/.ssh/authorized_keys`
on both Macs, so any fleet machine can `ssh <host>.<tailnet>` without a
password. The var is the list at <https://github.com/dolfth.keys>. To
retire a machine, drop its key from both GitHub and the var. Keys added
by hand on a host do not survive the next bootstrap.

The NixOS server nwa is not bootstrapped from this repo. Its flake owns
authorized_keys. It runs Tailscale SSH, whose first connection from a
new key prints an approval URL. This key can be approved persistently in
the Tailscale admin console, or every unattended probe (the `nwa-health`
agent) waits on approval.

After a power cut gza will restart automatically. For unlocking FileVault
remotely gza keeps password auth (`man apple_ssh_and_filevault`) as keys
are inside the FileVault volume.

## Day to day

```bash
# To apply everything (hooks + packages + dotfiles):
cd ~/.config/mise && mise bootstrap

# To see the file list; `mise dot diff` previews changes
mise dot status

# To commit and push
git commit -am "…"; git push
```

Edit a template: preview with `mise dot diff`, re-render with
`mise dot apply`. To audit coverage, `mise dot files <path>` shows
per-file state `tracked`/`excluded`/`omitted`/`untracked`/`partial` and
why.

`mise bootstrap --update` fast-forwards `~/.config/mise` with
`git pull --ff-only` and re-runs the whole bootstrap from the new
commit. If a diverged checkout stops the run: pull by hand, then re-run.

When a machine leaves the fleet or a module is retired:
`mise bootstrap unapply` removes the dotfiles, packages, and services.

## Fleet sync

Any machine can orchestrate a sync by:

```bash
cd ~/.config/mise
mise bootstrap remote --adopt 'git@github.com:dolfth/dotfiles.git?ref=main' --update
```

This connects over SSH to every machine in the `[bootstrap.remote.hosts]`
inventory (`mise.toml`) and, on each one, adopts this checkout as its
`~/.config/mise`. The `--update` option fast-forwards an existing
checkout so a host behind `main` does not re-apply its stale commit. It
then runs the full `mise bootstrap` there.

## Config layout

| File | Loads when | Holds |
|---|---|---|
| `mise.toml` | always | the config both Macs share: fallback identity vars (host/accent/icon), `omp_base`, tailnet and `ssh_keys`, the pinned release versions the fetching tasks and pin-check read, macOS defaults, `$EDITOR`/`$VISUAL` (helix), shared dotfiles, the syncthing and pin-check LaunchAgents, the bootstrap hooks, the fleet inventory for sync |
| `mise.mca.toml` | `mca` selected | the laptop: host identity vars |
| `mise.gza.toml` | `gza` selected | the desktop: the llama-swap and omlx LaunchAgents plus the six agent-job clocks, the herdr, llama-swap, omp, omlx and pi configs, `WIRED_LIMIT_MB`, `LLAMA_SWAP_KEY`, the LuxMini pref |
| `miserc.local.toml` | never committed | this machine's selection: `env = ["<host>"]`; the pre-packages hook writes it on a fresh checkout |
| `Brewfile` | brew-bundle task | the brew formulae, casks, and App Store apps both Macs share |
| `Brewfile.gza` | brew-bundle task, gza | the additional desktop packages: omlx + splash + llama-swap + herdr + nono |

The selection in `miserc.local.toml` names this machine's module, 
everything else is shared by both Macs.

`brew bundle` (the brew-bundle task) just installs what is missing. 
Upgrades are done by the function `up`.

Homebrew installs the tapped servers mise cannot reach: omlx, splash
and llama-swap (mise's formula shim lacks their taps' brew DSL, and
resolution is all-or-nothing per batch). The dotfiles, tasks and hooks,
launchd agents and macOS defaults are mise's. omp, LuxMini and pared
(the Apple Intelligence removal) fit neither ecosystem: no formula, no
mise backend, so their respective tasks installs their pinned,
checksum-verified GitHub release: dev-agents the omp binary, luxmini
the DMG, apple-intelligence the tarball.

## Files (`[dotfiles]`)

| Source | Target | Mode | Notes |
|---|---|---|---|
| `zshenv` | `~/.zshenv` | copy | the brew PATH and `$EDITOR` for `$SHELL -c` child shells where mosh's ssh finds `mosh-server` |
| `zshrc` | `~/.zshrc` | copy | starts fish |
| `ssh_config` | `~/.ssh/config` | copy 0600 | a symlink would expose the repo file's permissions to ssh |
| `ssh/authorized_keys.tera` | `~/.ssh/authorized_keys` | render 0600 | the `ssh_keys` var; hand-added keys need to go into the var |
| `fish/config.fish` | `~/.config/fish/config.fish` | symlink | the mise activation block |
| `fish/functions/*.fish` | `~/.config/fish/functions/` | symlink | `up` for upgrades, `mkd` for new directory, `tstat` for tailnet peers, `port` for holder of a port |
| `starship.toml.tera` | `~/.config/starship.toml` | render | per-host accent and icon from the vars |
| `git/config` | `~/.config/git/config` | symlink | signs commits and tags with `~/.ssh/id_ed25519` |
| `git/allowed_signers.tera` | `~/.config/git/allowed_signers` | render | every host's public key (the `ssh_keys` var) |
| `ghostty/config` | `~/.config/ghostty/config` | symlink | Nerd Font, so starship's glyphs render |
| `aerospace/aerospace.toml` | `~/.config/aerospace/aerospace.toml` | merge | AeroSpace rewrites the file itself when the layout changes in-app |
| `herdr/config.toml` | `~/.config/herdr/config.toml` | copy | gza; herdr rewrites the file itself (reset-keys, first-run wizard) |
| `linearmouse.json` | `~/.config/linearmouse/linearmouse.json` | merge | fills only the missing keys; LinearMouse owns the file afterwards |
| `handy/settings_store.json` | `~/Library/Application Support/com.pais.handy/settings_store.json` | symlink | Handy saves the store with a plain write, so in-app edits land in the repo: commit them. Where Handy already ran, `mise dot add` adopts the live file first |
| `pi/agent/settings.json` | `~/.pi/agent/settings.json` | merge | gza; the two pinned keys, deep-merged into the file pi writes |
| `omlx/*.json` | `~/.omlx/` | render + merge | gza; the repo's keys deep-merged into omlx's files, so its own auth keys and model list survive; `settings.json` held 0600 even if recreated |
| `omp/agent/config.yml` | `~/.omp/agent/config.yml` | symlink | gza; `/settings` changes flow back into the repo: commit them |
| `omp/agent/models.yml.tera` | `~/.omp/agent/models.yml` | render | gza; the pool's catalog, one endpoint behind llama-swap (see Desktop services) |
| `llama-swap/config.yaml.tera` | `~/.config/llama-swap/config.yaml` | render | gza; the pool's front door (see Desktop services) |

Modes: symlink is the mise default; copy writes the file; render expands
the `.tera` template first; merge rewrites only the repo's keys, at the
target file's top level, and leaves the app's own keys alone -- the id
after the target path (`pinned`, `initial`) names the merge, it is not
a key in the file. `zshenv`/`zshrc` copy where the default would
symlink: the omp sandbox denies `~/.zshrc`, and a deny follows a symlink
into the repo, denying the agent the repo's own copy.

Rows without a host apply to every machine. Files on disk that no module
declares are left alone. To delete a deployed file, declare it
`mode = "absent"`. `mise dot unapply` removes what the config still
declares, so run it before deleting a declaration, not after.

### The omp agent sandbox (gza)

There are three ways to run omp in a nono sandbox: `omp`, `local-omp`,
 `nwa-omp`. Each is a root:wheel wrapper plus a nono profile under
`/usr/local` installed by `dev-agents`.

| Source | Target | Notes |
|---|---|---|
| `nono/omp.json` | `/usr/local/etc/nono/omp.json` | the daily Seatbelt profile, installed by copy since the agent must not edit its own sandbox. Denies `~/.omp/profiles` (the offline profiles' state) and `/usr/bin/ssh` |
| generated from `omp.json` + `vars.omp_base` | `/usr/local/etc/nono/local-omp.json` | the offline profile: allow-list of the model host only, so the two profiles cannot drift |
| generated from `omp.json` | `/usr/local/etc/nono/nwa-omp.json` | the ssh-capable nwa profile: undoes the ssh deny, denies `~/.tsk`, carries no network policy (invariant 12) |
| `nono/omp-wrapper.sh` | `/usr/local/bin/omp` | the name on PATH is the wrapper, so `omp` launches are sandboxed; the unsandboxed one is an explicit `omp-unsandboxed` |
| `nono/local-omp-wrapper.sh` | `/usr/local/bin/local-omp` | offline work: `OMP_PROFILE=local` relocates sessions, logs and memory into `~/.omp/profiles/local`, which the daily profile denies. Runs `nono run` -- the allow-list filter needs the supervisor's proxy |
| `nono/nwa-omp-wrapper.sh` | `/usr/local/bin/nwa-omp` | the one entry with ssh, exclusively for nwa: start it from the nixos-config checkout; `OMP_PROFILE=nwa`, host keys in the profile tree's own `known_hosts` |
| `nono/AGENTS-sandbox*.md` | `~/.omp/agent/AGENTS.md` and the two profile trees | the note each agent loads |

## Tasks and hooks (`mise-tasks/`)

| Task | Hook | Does |
|---|---|---|
| `defaults-snapshot` | pre-packages | hashes the defaults domains the UI reads, before bootstrap writes them |
| `brew-bundle` | pre-packages | `brew bundle` over `Brewfile` + `Brewfile.<host>`; a failed entry warns and continues -- re-run in a terminal. No-op off macOS |
| `luxmini` | pre-packages (gza) | installs the pinned, checksum-verified LuxMini DMG; never downgrades. First app launch shows helper's admin approval |
| `bootstrap` | the `bootstrap` slot | self-heals the `dev.mise.*` agents: loads what is not loaded, kickstarts dead ones, reports the port holders; seeds the agent state trees and the llama-swap API key. No-op off macOS; on mca it heals pin-check |
| `herdr-plugins` | final | installs tab-rename, registers the tsk board plugin, installs the tsk agent skill; no-op where herdr is absent |
| `vscode-extensions` | final | the vscodium extensions; no-op where codium is absent |
| `dev-agents` | final (gza) | installs the omp sandbox and machine-checks its invariants (the 1--12 list in the script's header): pinned raw binary, root:wheel profiles and wrappers under `/usr/local`, the shadowing brew omp removed, `sign.pub`/`known_hosts` and the `local`/`nwa` state trees seeded. `dev-agents check` is the sudo-free half; the install needs a TTY |
| `system-check` | final | the non-declarative macOS settings: FDA-gated app defaults, the Downloads Dock tile, the Bluetooth menu item, hostname, firewall, the tailnet resolvers in resolv.conf, Touch ID, power, the update policy, the FileVault check; the desktop adds the GPU wired-limit daemon, Screen Sharing and Remote Login. The sudo part needs a TTY; Dock/Finder restart only when a domain they read changed |
| `apple-intelligence` | final | pared: every feature off (Siri included), the managed profile kept installed (one System Settings click), downloaded models removed. Apple-silicon macOS 27+ only |
| `finder-favorites` | final | sidebar Favorites := exactly the visible `$HOME` directories; Finder stores them as an LSSharedFileList archive, so the task writes through that API -- no-interaction flags, 90 s watchdog, a converged list is a no-op |
| `inventory` | manual (Macs) | the diffable manifest of this Mac's app state, each line annotated with its owner (`repo`, `brew:<token>`, `sync`, `?`); the diff of the two Macs is the transfer backlog. Refuses inside the omp sandbox -- run it in a terminal |
| `check` | git hooks + final | the repo self-test, five legs (its header); the pre-commit/pre-push hooks refuse unchecked trees via a tree-hash marker, the dot-diff leg asserts this run converged, the heartbeat legs catch dead schedules. A GitHub Actions workflow re-runs the portable legs on every push, mise at the `min_version` floor |
| `pin-check` | weekly agent (Macs) | HEADs every pinned release asset; one heartbeat line per run in `~/Library/Logs/pin-check.log`, whose age `check` reads as the agent's liveness |
| `ha-monitor` | daily agents (gza) | the read-only Home Assistant check: the HA repo is the work dir (its AGENTS.md and read-only MCP are the context), only the notes and the report draft writable (brief: `agent-jobs/ha-monitor.md`). State and the shared harness (`report`, `profile`, dry-run) live in `~/.local/state/agent-jobs/` and `mise-tasks/_agent-job.sh` |
| `ha-update` | weekly agents (gza) | installs pending HA updates over the API -- ordered, backup-first, stop at the first failure (brief: `agent-jobs/ha-update.md`). It mutates HA: the network allow-list is the write guard |
| `nwa-health` | daily agents (gza) | probes nwa from gza over Tailscale SSH, read-only (brief: `agent-jobs/nwa-health.md`); the probes are scripted ssh in the task, the model writes notes and report from the bundle only -- supervised, ssh denied, empty allow-list. `mise run nwa-health seed` copies the notes from nwa |

Tasks run on every `mise bootstrap`. The macOS-only tasks carry the
`macos` tag and the gza agent jobs carry `gza` (mise >= 2026.11.2), 
so a group can be selected explicitly -- `mise run --tag macos`, 
`mise tasks ls --tag gza`. `--output summary` collapses a
multi-task run to one line per pass; with `task.logs = true`
(mise >= 2026.11.3) a failed task's full output is kept for
`mise tasks log NAME`. 

The pre-packages hook opens with a config gate:
`mise env` over the loaded config, failing the run when the config does
not parse or contains unknown fields -- normally a typo'd key only
warns, and then brew, downloads and system check would run.

Values the tasks need but the repo must not carry live outside it: the
HA address at `~/.config/ha/host` (gza, copied from nwa's HA repo), and
the tailnet domain, which the tasks read from the resolver Tailscale
installs (`scutil --dns`). A job missing its value skips and says so in
the heartbeat.

# Desktop services (gza)

`llama-swap` (port 9292) is the inference proxy. Its 
LaunchAgent keeps one of the two splash servers for the two Qwen3.8
models resident. The 27B is on 127.0.0.1:8000, the Flash-Next on 
127.0.0.1:8100. A request naming the other model ID stops the
running engine, loads the requested one, then answers. The engines
bind loopback; only llama-swap faces the tailnet.

The GPU wired-memory limit (the 96 GiB fuse system-check installs)
makes the pool single-tenant. Loading two OOM-crash each
other's Metal clients. 

omlx (port 8080) is installed and declared with RunAtLoad off, but it
is out of the pool. There is no omlx provider in 
`omp/agent/models.yml.tera` but manually starting omlx beside a loaded
engine breaks the single-tenant rule. 

Bootstrap task restarts a dead llama-swap on every run and seeds the 
API key in `~/.config/llama-swap/api_key`, outside this repo. Upgrading
with `up` restarts llama-swap when the llama-swap or splash keg moves.
Logs: `~/Library/Logs/omlx.log` and `~/Library/Logs/llama-swap.log`;

The same box hosts the scheduled omp agent jobs: `ha-monitor` (04:38,
reported 12:03 via ntfy), `ha-update` (Fri 02:33, reported 06:03), and
`nwa-health` (06:13, reported 12:03, probing nwa over Tailscale SSH).

## Pitfalls

Known traps. Each is cheap to hit and expensive to diagnose.

- `-E <name>` reaches that one command; `--save-env` is what writes it
  to `miserc.local.toml` for every later mise command. Without `-E`
  the hook, on a fresh checkout, selects the module matching the
  machine's hostname, or leaves the selection empty and prints the
  available names; a re-run of the bootstrap loads whatever the file
  now says.
- mise reads `miserc.local.toml` only from `~/.config/mise/`. A copy one
  level up is silently ignored: the vars fall back to the base values and
  the host module's dotfiles never deploy.
- The cwd trap is gone on mise 2026.11.8: from the home directory the
  vars come from the host module (checked with `mise vars`). mise once
  honored the selection only inside `~/.config/mise` and fell back to
  the base values outside it -- the fallback host icon, the FQDN
  `omp_base` -- which a plain `ssh host mise ...` (cwd = home) hit.
- A mise below the `min_version` floor in `mise.toml` refuses every
  command with an upgrade hint. `brew upgrade mise` and re-run.
- Do not `chsh` to fish. `~/.zshrc` starts fish for interactive sessions,
  so `$SHELL` stays POSIX for software that runs `$SHELL -c '...'`.

Replacing a machine under the same hostname: take the old box off the
tailnet first -- power it off or have it leave -- *before* step 5. The
system-check task sets the hostname and the agents register under it, so
two live `gza`s split MagicDNS. Then swap the host key: the new
`~/.ssh/id_ed25519.pub` goes into `vars.ssh_keys` (`mise.toml`) and onto
<https://github.com/dolfth.keys>, and the old key comes out of both.
Commits signed by an unlisted key fail verification on the other hosts.

If `mise bootstrap` refuses to run the `bootstrap` task as "not
trusted": the checkout predates the `trusted_config_paths` entry in
`mise.toml`. `git pull` and re-run, or record the checkout locally with
`mise trust mise-tasks/bootstrap` (plain `mise trust ~/.config/mise`
normalizes to the already-trusted home and records nothing).
