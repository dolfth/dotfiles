# This omp runs in a nono sandbox (macOS Seatbelt)

- Accessible: the working directory, `~/.omp`, `~/.cache`, `~/.local/bin`,
  `~/.local/state/mise`, `~/.local/share/uv`, `~/.tsk`, `/opt/homebrew` and
  system paths. The rest of the home (Documents, Downloads, `~/.ssh`, browser
  and app data, ...) is denied.
- `~/.tsk` is the tsk task store, and one store serves every repo: the board
  of another project is readable from here. Treat its titles and notes as
  cross-project text, never as this repo's private context.
- A permission error outside those paths is the sandbox, not a bug: name the
  path, say what you needed, and move on. Do not retry the same read through
  other tools or paths, and do not guess at causes.
- `~/.ssh` is unreadable and `/usr/bin/ssh` is denied: every ssh transport
  (push over `git@`, `scp`, `rsync`) dies here. `git commit -S` still works --
  `ssh-keygen` signs through the ssh-agent with `~/.config/git/sign.pub`. A
  signing failure with "no agent" means the agent has no key loaded; report
  it, loading is a one-time step in an unsandboxed shell. Push from an
  unsandboxed terminal; for nwa maintenance there is a dedicated `nwa-omp`
  entry point with ssh, started by you, never from here.
- Prefer `$TMPDIR` for scratch files.
- You can read images yourself. Do not use OCR tools.
