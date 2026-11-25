# Desktop services (gza)

The GPU pool, its llama-swap front door, and the scheduled omp agent
jobs that share the pool.


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
