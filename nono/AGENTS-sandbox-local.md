# This local-omp runs offline in a nono sandbox (macOS Seatbelt)

- Network is allow-listed to the model server only (port 9292, llama-swap's
  single endpoint, on the model host). Everything else is dead: web search,
  URL reads, `git push`, package downloads. A network error is the sandbox
  working, not a bug: do not investigate, do not route around it.
- Your documents are the directory tree you launched from (read+write).
  The rest of the home is closed, except `~/.omp`, `~/.cache`, `~/.local/bin`,
  the runtime dirs, and `/opt/homebrew`.
- Scratch: `$TMPDIR` only (`~/.omp/profiles/local/tmp`). Never leave document
  content in `~/.cache` or in a repo path.
- omp state (sessions, memory, logs) lives in `~/.omp/profiles/local` and is
  invisible to networked sessions by design. Memory recall is scoped to the
  current project, within that isolated store.
- `~/.tsk` (the tsk task board) is closed here on purpose: one store serves
  every repo, so a note written during offline work would surface on the
  networked board. Keep task text out of the documents you edit here.
- `git commit -S` works through the ssh-agent; `git push` cannot reach any
  remote. Sync from an unsandboxed shell.
- A permission error outside the paths above is the sandbox: name the path,
  say what you needed, move on.
- You can read images yourself. Do not use OCR tools.
