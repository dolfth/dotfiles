# Files (`[dotfiles]`)

Every declared file, its target, and the per-file rationale -- why a copy,
why a symlink, why a merge or deep-merge. The gza omp sandbox installs
(profiles, wrappers, agent notes) are in [sandbox.md](sandbox.md).


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
| `llama-swap/config.yaml.tera` | `~/.config/llama-swap/config.yaml` | gza; the pool's front door: the two splash engines bound to loopback, the flash-next preload, and the API key rendered from `~/.config/llama-swap/api_key` |

Rows without a host apply to every machine. Files on disk that no loaded
module declares are left alone; `mise dot prune` removes ones the repo
used to track. To delete a file the repo deployed, declare it
`mode = "absent"` in the module that used to own it.

