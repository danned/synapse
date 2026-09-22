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

## Progression and purchases

The browser slice persists its deck, Gene Shards, settings, tutorial state, and simulated entitlement under `user://`. The Gene Lab uses `DebugPurchaseProvider`; it never processes real money. A future native release can replace this provider with platform-specific billing while leaving collection and save logic unchanged.
