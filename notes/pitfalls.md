# Pitfalls

Known traps. Each is cheap to hit and expensive to diagnose.

- The `-E <name>` you give `mise bootstrap` is written to
  `miserc.local.toml` and every later mise command on the machine uses
  it. Without `-E` the hook selects the module matching the machine's
  hostname, or leaves the selection empty and prints the available
  names; a re-run of the bootstrap loads whatever the file now says.
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

If `mise bootstrap` refuses to run the `bootstrap` task as "not
trusted": the checkout predates the `trusted_config_paths` entry in
`mise.toml`. `git pull` and re-run, or record the checkout locally with
`mise trust mise-tasks/bootstrap` (plain `mise trust ~/.config/mise`
normalizes to the already-trusted home and records nothing).

