# Lane-Switching Enemies

**Focus:** Enemy behavior

## Opportunity

Every enemy currently follows its assigned lane. Once a player learns the fixed routes, the same links can cover predictable traffic each run.

## Idea

Add a rare enemy that can change from one lane to the other at a marked junction. Telegraph the intended switch before the enemy reaches it; the choice is deterministic from the run seed and visible in Easy and Normal intel. A slow or root applied before the junction delays the switch, giving pulse timing a way to intercept it. Keep the junction away from the Core and ensure both resulting routes are valid.

## Why it helps

The threat asks for flexible coverage without changing every enemy into a surprise. The marked junction becomes a meaningful network-design landmark.

## Design check

Use only a few hand-checked junctions per level. Never change lanes without an on-board cue, especially on Hardcore.
