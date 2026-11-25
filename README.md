# dotfiles

Two Macs, configured by [mise](https://mise.jdx.dev) from this repo:

| Host | OS | What it is |
|---|---|---|
| `mca` | macOS | laptop |
| `gza` | macOS | desktop: always-on llama-swap front for the two splash pool models (omlx installed, out of pool), omp host |

nwa, the NixOS server, left the mise fleet (2026-11-25): no mise there,
its flake owns the whole machine. gza still monitors it -- the
`nwa-health` job probes it over Tailscale SSH -- and maintains its
flake over ssh through the `nwa-omp` entry point.

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

Pitfalls:

- `-E mac,gza` is written to `miserc.local.toml` and every later mise
  command on the machine uses it. Without `-E` the hook writes
  `["mac"]` (the laptop defaults) and tells you to re-run with the host
  name added.
- mise reads `miserc.local.toml` only from `~/.config/mise/`. A copy one
  level up is silently ignored: the vars fall back to the base values and
  the host module's dotfiles never deploy.
- On mise 2026.11.8 the selection is honored only when the command runs
  with `~/.config/mise` as the working directory. From any other cwd the
  vars fall back to the base values: a bare `mise dotfiles apply` from
  the home directory rewrote the templated files with base values (the
  fallback host icon, the FQDN `omp_base`). Run every repo mise command
  from inside the repo. A plain `ssh host mise ...` (cwd = home) is the
  same trap.
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
| `mise.mac.toml` | `mac` selected | both Macs: the declarative macOS defaults, `$EDITOR`/`$VISUAL` (helix), `~/.zshenv`, `~/.zshrc`, `~/.ssh/config`, the fish functions, linearmouse |
| `mise.mca.toml` | `mca` selected | the laptop: host identity vars (host/accent/icon, HOST/KIND) |
| `mise.gza.toml` | `gza` selected | the desktop: the llama-swap and omlx LaunchAgents, the omp, omlx, pi and herdr configs, the llama-swap front door's config; its brew entries, the agent stack included, are in `Brewfile.gza` |
| `miserc.local.toml` | never committed | this machine's selection: `env = ["mac", "<host>"]` |
| `Brewfile`, `Brewfile.gza` | the brew-bundle task | the brew manifest: the shared entries, plus the desktop's servers and agent stack |

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

| Source | Target | Notes |
|---|---|---|
| `zshenv` | `~/.zshenv` | both Macs; the brew PATH and `$EDITOR` for `$SHELL -c` child shells -- the only zsh file they read, so it is where mosh's ssh finds `mosh-server`. Copied, same reason as `~/.zshrc` |
| `zshrc` | `~/.zshrc` | both Macs; starts fish. Copied -- the omp sandbox's `~/.zshrc` deny follows a symlink into the repo, which would deny the repo's own copy from the sandboxed agent |
| `ssh_config` | `~/.ssh/config` | copied at 0600 -- a symlink would expose the repo file's permissions to ssh; key passphrases live in the Keychain |
| `ssh/authorized_keys.tera` | `~/.ssh/authorized_keys` | the Macs; the `sshKeys` var rendered, 0600. The file is mise's: hand-added keys need to go into the var |
| `fish/config.fish` | `~/.config/fish/config.fish` | both Macs; the mise activation block |
| `fish/functions/*.fish` | `~/.config/fish/functions/` | Macs. `up` upgrades everything, `mkd` makes and enters a directory, `tstat` lists the tailnet peers, `port` shows who holds a port |
| `starship.toml.tera` | `~/.config/starship.toml` | per-host accent and icon from the vars |
| `git/config` | `~/.config/git/config` | signs commits and tags with `~/.ssh/id_ed25519` |
| `git/allowed_signers.tera` | `~/.config/git/allowed_signers` | every host's public key (the `sshKeys` var) |
| `ghostty/config` | `~/.config/ghostty/config` | Nerd Font, so starship's glyphs render |
| `aerospace/aerospace.toml` | `~/.config/aerospace/aerospace.toml` | both Macs; merged -- AeroSpace rewrites the file itself when the layout changes in-app |
| `herdr/config.toml` | `~/.config/herdr/config.toml` | gza; copied -- herdr rewrites the file itself |
| `linearmouse.json` | `~/.config/linearmouse/linearmouse.json` | written only if absent, then LinearMouse owns it |
| `handy/settings_store.json` | `~/Library/Application Support/com.pais.handy/settings_store.json` | Macs; symlinked -- Handy saves the store with a plain write, so in-app settings edits flow back into the repo: commit them. On a host where Handy already ran, `mise dot add` adopts the live file (it captures the source before linking) |
| `pi/agent/settings.json` | `~/.pi/agent/settings.json` | gza; two pinned keys deep-merged into the file pi writes |
| `omlx/*.json` | `~/.omlx/` | gza; the pinned settings deep-merged into the files omlx writes (auth keys stay omlx's), plus server aliases for the host's `.local` and Tailscale names |
| `omp/agent/config.yml` | `~/.omp/agent/config.yml` | gza; symlinked -- `/settings` changes flow back into the repo -- commit them |
| `omp/agent/models.yml.tera` | `~/.omp/agent/models.yml` | gza; the splash provider behind llama-swap: both pool models on the one 9292 endpoint; `baseUrl` renders from `vars.omp_base` (`127.0.0.1` on gza); `apiKey` reads `~/.config/llama-swap/api_key` by `exec()` |
| `llama-swap/config.yaml.tera` | `~/.config/llama-swap/config.yaml` | gza; the pool's front door: the two splash engines (the retired splash LaunchAgents' serve flags, loopback binds), the flash-next preload, the same API key rendered from `~/.config/llama-swap/api_key` |
| `nono/omp.json` | `/usr/local/etc/nono/omp.json` | gza; the Seatbelt profile for omp, installed root:wheel by the `dev-agents` task -- by copy, never a repo symlink: the sandboxed agent must not be able to edit its own sandbox. Denies `~/.omp/profiles`, the state of the omp named profile `local`, so networked sessions cannot read sensitive work. Denies `/usr/bin/ssh`: the binary file deny is the only kernel-enforced ssh guard on macOS (Seatbelt cannot filter egress by port, the domain proxy cannot carry ssh), so the daily agent has no ssh transport at all -- push needs https; `ssh-keygen` survives for commit signing |
| (generated from `nono/omp.json` + `vars.omp_base`) | `/usr/local/etc/nono/local-omp.json` | gza; the offline profile for sensitive work, built by `dev-agents` instead of stored -- the two profiles cannot drift. Adds the model host's network allow-list (`network.block` would kill loopback too, invariant 8) and restores the state-tree deny carve-out |
| (generated from `nono/omp.json`) | `/usr/local/etc/nono/nwa-omp.json` | gza; the ssh-capable nwa-maintenance profile, generated like local-omp's: undoes the daily `/usr/bin/ssh` deny and denies `~/.tsk`; carries no network policy -- an allow-list could not survive `nono wrap` and could not carry ssh even supervised (nolabs-ai/nono#756), so `dev-agents` rejects a `network` key there as a lie (invariant 12) |
| `nono/omp-wrapper.sh` | `/usr/local/bin/omp` | gza; root:wheel, so `omp` on PATH -- and every launch by name, `herdr agent start` included -- is sandboxed. Raw binary: `omp-unsandboxed`. Redirects Bun's install cache to `~/.omp/cache/bun-install` (`~/.bun` is denied; the memory embedder installs its runtime with Bun). The port of nwa's `dev-agents.nix`; requirements in the task's header |
| `nono/local-omp-wrapper.sh` | `/usr/local/bin/local-omp` | gza; root:wheel; the offline entry point for sensitive work. `OMP_PROFILE=local` relocates omp's state -- sessions, logs, the mnemopi store -- into `~/.omp/profiles/local`, which the daily profile denies; scratch lives there too. Runs `nono run`, not wrap: the domain allow-list is a proxy feature and the proxy needs the supervisor -- under wrap the same profile enforces nothing. `vars.omp_base` on the GPU-pool ports is the only reachable network |
| `nono/nwa-omp-wrapper.sh` | `/usr/local/bin/nwa-omp` | gza; root:wheel; the one omp entry point with ssh, exclusively for maintaining nwa: launch it from the nixos-config checkout, `--allow-cwd` makes that tree its whole document world. `OMP_PROFILE=nwa` relocates state into `~/.omp/profiles/nwa`, invisible to the daily sandbox; `~/.ssh` stays denied there too, so host keys live in the profile tree's own `known_hosts` (seeded from the `~/.config/git` copy, tailscale keys arriving accept-new) and `GIT_SSH_COMMAND` points git at the same file. Runs `nono wrap`: there is no network filter it could host, and wrap keeps the herdr foreground label |
| `nono/AGENTS-sandbox.md` | `~/.omp/agent/AGENTS.md` | gza; the note omp loads into every session, so a sandbox denial costs one line, not a token-spending investigation |
| `nono/AGENTS-sandbox-local.md` | `~/.omp/profiles/local/agent/AGENTS.md` | gza; the offline variant of the note, installed into the `local` omp profile the wrapper selects; the `local` agent dir also gets symlinks to the rendered `models.yml`/`config.yml` and the shared runtime caches |
| `nono/AGENTS-sandbox-nwa.md` | `~/.omp/profiles/nwa/agent/AGENTS.md` | gza; the nwa-maintenance note, installed into the `nwa` omp profile: the ssh incantation with the profile-tree `known_hosts`, the Tailscale-SSH approval caveat (an unregistered key makes every connect wait on a browser URL), the E1 deploy path -- edit the flake, push, `nixos-rebuild switch --flake github:...#nwa` over ssh, nwa builds its own system; the `nwa` agent dir also gets the config and cache symlinks |

Rows without a host apply to every machine. Files on disk that no loaded
module declares are left alone; `mise dot prune` removes ones the repo
used to track. To delete a file the repo deployed, declare it
`mode = "absent"` in the module that used to own it.

## Tasks and hooks (`mise-tasks/`)

| Task | Hook | Does |
|---|---|---|
| `defaults-snapshot` | pre-packages | hashes the defaults domains the UI reads, before bootstrap writes them |
| `brew-bundle` | pre-packages | `brew bundle` over `Brewfile` + `Brewfile.<host>`: installs what is missing, never upgrades (`up` does); a failed entry warns and continues -- re-run `brew bundle` in a terminal. No-op off macOS |
| `bootstrap` | the `bootstrap` task slot | for each `dev.mise.*` LaunchAgent: a guarded `launchctl bootstrap` (loads only a not-yet-loaded job) plus a bare `kickstart` (starts a dead agent, no-op on a healthy one -- never kills a running server); then reports who holds each port; also seeds the ha-monitor state tree, since the token copy targets it before the first run. No-op off gza |
| `herdr-plugins` | final | the herdr plugins the keybindings rely on: installs tab-rename, registers the tsk board plugin and installs the tsk agent skill (`tsk setup herdr`, `tsk setup agents --yes`, skipped where tsk is absent), reloads a running server; no-op where herdr is absent |
| `vscode-extensions` | final | the vscodium extensions; no-op where codium is absent |
| `dev-agents` | final (gza; skips elsewhere) | the gza omp sandbox (nwa's dev-agents.nix ported to Seatbelt): checks the profile's invariants (herdr socket denied, HERDR control vars stripped, profile by path, root-owned, no `$HOME`/`~/.ssh` grants, personal documents unreachable through default-deny -- no deny rule there, which would outrank the workdir grant, the shared tsk store `$HOME/.tsk` granted to the daily profile and denied to local-omp, `/usr/bin/ssh` denied to the daily profile with the deny lifted in the generated `nwa-omp` profile alone -- invariants 11 and 12), installs the pinned raw binary plus the root:wheel profiles and wrappers (`omp`, `local-omp`, `nwa-omp`) under `/usr/local`, removes the brew omp that would shadow it, seeds the agent's `sign.pub`/`known_hosts` copies and the `local` and `nwa` state trees. `dev-agents check` is the sudo-free static half. The sudo part needs a TTY |
| `system-check` | final | the macOS system settings: FDA-gated app defaults, the Downloads Dock tile (`persistent-others` is outside mise's `dock.apps` and the tile needs `$HOME`, so like Finder's home target the task keeps it), the Bluetooth menu-bar item (volume has no public key -- private per-machine ControlCenter blobs, so it stays manual), hostname, firewall, the tailnet resolvers in resolv.conf, Touch ID, power, updates, the FileVault check, the GPU wired-limit daemon; the desktop also gets Screen Sharing and Remote Login. The sudo part needs a TTY. Dock/Finder/… restart only when a domain they read changed |
| `apple-intelligence` | final | the Apple Intelligence removal via the pinned pared release: disables every feature in its catalog (Siri included), keeps the managed profile installed (one System Settings click per machine), removes downloaded models. Runs only on Apple-silicon macOS 27+ |
| `finder-favorites` | final | Finder sidebar Favorites := exactly the visible `$HOME` directories, alphabetically -- hand-pinned tiles (the stock Applications one included) and stale bookmarks are removed, like the Dock rule. Favorites are an LSSharedFileList archive, not a defaults domain, so the task writes through that (deprecated, alive) API; Finder updates live and a converged list is a no-op. Bookmarks are only ever resolved with no-interaction/no-mount flags and the run has a 90 s watchdog, so a stale item can never block the bootstrap. No-op off macOS |
| `tailscale-ssh` | manual (Macs) | advertise Tailscale SSH on the CLI tailscaled (`tailscale set --ssh`) and report; refuses from a tailnet SSH session (interception would hang it) and while the app variant is installed. Variant cutover itself is the README's manual sequence |
| `inventory` | manual (Macs) | the diffable manifest of this Mac's app state -- Application Support dirs, sandboxed containers, Group Containers, non-Apple prefs domains, LaunchAgents, the accounts table -- saved to `~/Library/Logs/inventory-<host>.txt`, each line annotated with its owner: `repo` (a dotfiles target or a declarative domain), `brew:<token>` (an installed cask's bundle id or app name), `sync` (a syncthing share), `?` (nobody). The diff of the two Macs' manifests is the transfer backlog; a `?` row on one host alone is untransferred unowned state, and an account row it lacks means sign into it there (credentials stay in the first host's keychain). Sizes print to stdout only, keeping the saved files stable to diff. Refuses inside the omp sandbox, which denies the app-support trees -- run it in a terminal |
| `check` | git hooks + final hook (Macs) | the repo self-test, wired automatic on both ends of every change: the pre-commit/pre-push hooks (`mise-tasks/hooks`; `core.hooksPath` set by the pre-packages hook, so adopting the repo adopts the gate) refuse unchecked trees -- a tree-hash marker lets already-checked ones through silently, `--no-verify` skips the commit and the push gate then catches it -- and the final hook ends every bootstrap with it, where the dot-diff leg is the run's own idempotence assertion. Legs: the config gate (the pre-packages hook's assertion at commit-time), shellcheck over the task scripts, `mise dot diff` emptiness (a non-empty diff is drift -- fail), and the weekly pin-check heartbeat's freshness (a log older than 8 days is a dead agent; nine days of grace after a fresh install), plus the gza-only ha-monitor heartbeat (both agents loaded, a dated line at most 2 days old; the leg skips where the plist is absent). The dot-diff leg self-skips inside the omp sandbox, whose profile denies the dotfiles' target paths |
| `pin-check` | weekly agent + manual (Macs) | probe the pinned GitHub release URLs -- the omp binary of `dev-agents`, the pared tarball and checksum sidecar of `apple-intelligence` -- with the versions parsed from their single sources of truth, so a bump needs no edit here and a parse failure means those moved shape. The `dev.mise.pin-check` agent (`mise.mac.toml`, Wed 09:30) runs it; every run logs one line to `~/Library/Logs/pin-check.log` -- the log's age is the heartbeat's own liveness proof, which `check` reads -- and a broken pin raises a macOS notification and a non-zero exit |
| `ha-monitor` | daily agents + manual (gza) | the Home Assistant health check, moved from nwa's `hosts/nwa/agent-jobs/`: an omp run looks for oddities in HA over the API, changing nothing (`agent-jobs/ha-monitor.md`); its work dir is the HA repo (`~/Documents/code/homeassistant`, like nwa's `ha-api.nix`), so omp loads the repo's `AGENTS.md` and `.omp/mcp.json` as context and keeps its notes and report draft there; the generated profile grants the repo read and only those two files write, and its preflight reports a TCC denial on `~/Documents` as *unreadable*, distinct from *missing*. The state machine (skipped/result/failures, 30 days of run archives) lives in `~/.local/state/agent-jobs/ha-monitor/`. `dev.mise.ha-monitor` (04:38) runs it under `nono run` -- only the local model ports and HA at 192.168.0.253 are reachable; `dev.mise.ha-monitor-report` (12:03) posts the outcome to ntfy, silent when there is nothing to report, loud once on a new failure and once on recovery. Secrets copied from nwa once: the repo's `.ha_token` and `~/.local/state/agent-jobs/ntfy_topic`; `HA_MONITOR_DRYRUN=1` prints instead of posting |
| `ha-update` | weekly agents + manual (gza) | the Home Assistant updater, moved from nwa's `agent-job-ha-update`: an omp run installs pending HA updates over the API -- Supervisor, Core, add-ons, custom integrations, firmware, then OS, with `backup: true` where supported, release-notes gating, stopping at the first failure (`agent-jobs/ha-update.md` is nwa's brief, adapted). The ha-monitor pattern otherwise (HA repo as read work dir with only the report draft writable, state machine, 30-day archives, TCC-aware preflight) but this job MUTATES HA, so the network allow-list (HA + model ports only) is the write guard. `dev.mise.ha-update` (Fri 02:33, nwa's clock) runs it under `nono run`; `dev.mise.ha-update-report` (Fri 06:03) posts the outcome to ntfy. The heartbeat's stale window is 8 days: a weekly job is not dead at 25 h. Same secrets, same `HA_UPDATE_DRYRUN=1` |
| `nwa-health` | daily agents + manual (gza) | nwa's health check, moved from nwa's `agent-job-nwa-health` -- external monitoring now: an omp run probes nwa from gza over Tailscale SSH, read-only, changing nothing (`agent-jobs/nwa-health.md`). Its work dir is the nixos-config flake repo (`~/Documents/code/nixos-config`; its `AGENTS.md` is the context), with only `health-notes.md` and `report-draft.md` writable -- they need a `.gitignore` entry there, to land with the T9 cutover commit. The sandbox is the nwa-omp shape: `nono wrap` on a profile generated from the installed `nwa-omp` profile, because ssh cannot pass a domain allow-list (dev-agents #12) -- the filesystem grants are the whole sandbox story, and the preflight skips with a reason when `nwa:22` does not answer. nwa's clocks (`dev.mise.nwa-health` 06:13, report 12:03), ha-monitor's state machine and 2-day heartbeat, the same pinned splash-fn model: a model pick elsewhere can evict the engine mid-run, and the job swaps it back on its next request. `mise run nwa-health seed` copies `health-notes.md` from nwa once; removing the systemd timers is the nixos-config side of T9 |

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

`llama-swap` (port 9292) is the GPU pool's front door: one always-on
LaunchAgent that starts and stops the two splash servers -- the 27B
model on 127.0.0.1:8000, Flash-Next on 127.0.0.1:8100 -- and keeps
exactly one resident. A request naming the other model ID stops the
running engine, loads the requested one, then answers; the serve flags
are the retired splash LaunchAgents' own, moved into
`llama-swap/config.yaml.tera`, minus their network flags -- the engines
bind loopback, the front door faces the tailnet. The GPU wired pool
(the 96 GiB fuse system-check installs) is **single-tenant**: below the
fuse the kernel refuses nothing, so two resident servers OOM-crash each
other's Metal clients instead of queueing -- llama-swap's
one-model-at-a-time router is the guard the retired `gpupool` task held
by hand, and a model pick is now the switch. Flash-Next, the default
owner, is preloaded when llama-swap starts, so the ambient jobs answer
without paying a load.

omlx (port 8080) stays installed and declared, RunAtLoad off, but
**out of the pool**: llama-swap cannot evict a tenant it does not own,
so starting omlx beside a loaded engine is out of contract, and the
catalog (`omp/agent/models.yml.tera`) lists no omlx provider until it
rejoins.

Bootstrap rewrites plists when definitions change, the `bootstrap` task
restarts a dead llama-swap on every run and seeds the API key, and `up`
restarts the front door when the llama-swap or splash keg moves. Logs:
`~/Library/Logs/omlx.log`, `~/Library/Logs/llama-swap.log` (engine logs
arrive there too; the UI streams them per model).

9292 binds beyond loopback so tailnet clients -- another machine's
browser on the UI, an ad-hoc API call -- can reach the pool; no fleet
host uses it remotely today, the agent stack being gza-only. An API key
guards the endpoint and its UI at <http://127.0.0.1:9292/ui> -- one key
for everything it serves, kept in `~/.config/llama-swap/api_key` (0600,
outside the repo; the `bootstrap` task seeds it) and read into
llama-swap's config and the catalog by `exec()` at render time.

The engines answer on loopback too, unauthenticated -- loopback is
this host only; their chat pages are at <http://127.0.0.1:8000> and
<http://127.0.0.1:8100> while an engine is up.

The same box also hosts the scheduled omp agent jobs that nwa used to
run: `ha-monitor` (04:38, reported 12:03 via ntfy), `ha-update`
(Fri 02:33, reported 06:03) and `nwa-health` (06:13, reported 12:03 --
probes nwa from the outside, over Tailscale SSH). Their model is now a
local server, so the run no longer depends on this box being awake --
and the pool has no owner to lose: a model pick elsewhere can evict
flash-next mid-run, and the job's next request swaps it back, paying
the load once.
