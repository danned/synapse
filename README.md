# SYNAPSE

SYNAPSE is a mobile-first tower-defense vertical slice built with Godot 4.7.2. Towers form a directed power network: links affect enemies while pulses travel, and destination towers attack when those pulses arrive. Branching increases coverage but alternates pulse cadence between child routes.

## Run locally

```bash
godot --path .
```

The project uses a 1280×720 landscape reference viewport and supports both mouse and touch input.

## Tests

```bash
godot --headless --path . --script res://tests/run_tests.gd
```

## Web export

Install the Godot 4.7.2 web export templates, then run:

```bash
mkdir -p dist/web
godot --headless --path . --export-release Web dist/web/index.html
python3 -m http.server 8060 --directory dist/web
```

Open `http://127.0.0.1:8060/`. The export uses the Compatibility renderer and single-threaded WebAssembly.

## Isolated development sandbox

The Docker sandbox contains Codex CLI, Godot 4.7.2, Web export templates, native
runtime libraries, Git, Node.js, Python, compilers, and the command-line tools
needed to build and test the game. Build it once, then run the full suite:

```bash
./scripts/sandbox build
./scripts/sandbox test
```

The equivalent direct Compose commands are:

```bash
docker compose -f compose.sandbox.yaml build
docker compose -f compose.sandbox.yaml run --rm sandbox godot --version
```

Run the game as a Web export without sharing the host display server:

```bash
./scripts/sandbox web
```

Open `http://127.0.0.1:8060/`. The port is published on host loopback only.

To run Codex with full permissions inside the container, authenticate once and
start it from the repository root:

```bash
./scripts/sandbox login
./scripts/sandbox codex
```

`sandbox codex` deliberately disables Codex's inner approval sandbox. Docker is
the outer boundary: only this repository is bind-mounted, the container is not
privileged, no Docker socket or host home directory is mounted, and CPU, memory,
and process limits are applied. The container does have outbound network access,
which Codex and package managers require. Use full-access mode only for trusted
repositories because processes in the container can read the mounted repository
and the dedicated Codex credential volume.

Useful commands:

```bash
./scripts/sandbox shell
./scripts/sandbox run godot --version
./scripts/sandbox down
```

Set `SANDBOX_WEB_PORT`, `SANDBOX_MEMORY_LIMIT`, `SANDBOX_CPU_LIMIT`, or
`SANDBOX_PID_LIMIT` in the environment to override the defaults. The sandbox
image targets `linux/amd64`, and Docker can emulate it on supported ARM hosts.
Project `.env` files are ignored by Git to reduce the chance of committing
secrets.

## Progression and purchases

The browser slice persists its deck, Gene Shards, settings, tutorial state, and simulated entitlement under `user://`. The Gene Lab uses `DebugPurchaseProvider`; it never processes real money. A future native release can replace this provider with platform-specific billing while leaving collection and save logic unchanged.
