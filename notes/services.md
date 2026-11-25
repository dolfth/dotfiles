# Desktop services (gza)

The GPU pool, the llama-swap front door, and the omp agent jobs that
share the pool.

`llama-swap` (port 9292) is the GPU pool's front door: one always-on
LaunchAgent that starts and stops the two splash servers -- the 27B
model on 127.0.0.1:8000, Flash-Next on 127.0.0.1:8100 -- and keeps
exactly one resident. A request naming the other model ID stops the
running engine, loads the requested one, then answers. The engines
bind loopback; only llama-swap faces the tailnet.

The GPU wired-memory limit (the 96 GiB fuse system-check installs)
makes the pool single-tenant: below the limit the kernel refuses
nothing, so two resident servers do not queue -- they OOM-crash each
other's Metal clients. llama-swap's one-model-at-a-time router is the
enforcement. Flash-Next, the default owner, is preloaded when
llama-swap starts, so the scheduled jobs answer without waiting for a
model load.

omlx (port 8080) is installed and declared with RunAtLoad off, and it
is out of the pool: llama-swap cannot stop a server it does not own,
so starting omlx beside a loaded engine breaks the single-tenant rule.
The catalog (`omp/agent/models.yml.tera`) lists no omlx provider.

Bootstrap rewrites plists when definitions change, the `bootstrap`
task restarts a dead llama-swap on every run and seeds the API key,
and `up` restarts llama-swap when the llama-swap or splash keg moves.
Logs: `~/Library/Logs/omlx.log` and `~/Library/Logs/llama-swap.log`;
engine logs arrive there too, and the UI shows them per model.

9292 binds beyond loopback so tailnet clients -- a browser on the UI,
an ad-hoc API call -- can reach the pool. An API key guards the
endpoint and its UI at <http://127.0.0.1:9292/ui>. The key lives in
`~/.config/llama-swap/api_key` (0600, outside the repo; the
`bootstrap` task seeds it); llama-swap's config and the catalog read
it by `exec()` at render time. The engines also answer on loopback
without authentication; their chat pages are at
<http://127.0.0.1:8000> and <http://127.0.0.1:8100> while an engine is
up.

The same box hosts the scheduled omp agent jobs: `ha-monitor` (04:38,
reported 12:03 via ntfy), `ha-update` (Fri 02:33, reported 06:03), and
`nwa-health` (06:13, reported 12:03, probing nwa over Tailscale SSH).
Their model is a local server, so a run needs no external service. A
model pick elsewhere can evict flash-next mid-run; the job's next
request swaps it back and pays the load once.
