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
- `~/.ssh` is unreadable, but `git commit -S` and `git push` still work
  through the ssh-agent (signing uses `~/.config/git/sign.pub`, host keys use
  the copy under `~/.config/git`). If they fail with "no agent" or "host key
  verification failed", the agent has no key loaded -- report it; loading is a
  one-time step in an unsandboxed shell.
- Prefer `$TMPDIR` for scratch files.
- You can read images yourself. Do not use OCR tools.
