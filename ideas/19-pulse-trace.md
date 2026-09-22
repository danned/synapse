# Pulse Trace

**Focus:** Combat readability

## Opportunity

When a wave fails, several pulses, attacks, disables, and leaks may happen close together. A final recap helps, but the player also needs to see the decisive moment.

## Idea

Keep a short rolling record of board events during combat. After a wave or defeat, let the player scrub the last few seconds as a visual trace: pulse routes, disabled links, enemy positions, damage bursts, and leaks. Highlight the first leak or boss disruption by default. This is a local visualization of recorded events, not a second game simulation.

## Why it helps

Players can understand why a layout failed and make a targeted change. The same view makes successful combinations satisfying to revisit.

## Design check

Cap memory use for the Web build and keep the trace accessible without interrupting combat. If storage is tight, prioritize pulses, disables, and leaks over minor particles.
