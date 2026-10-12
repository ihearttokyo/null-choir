# Exact source-debug projectile observation

The optional `_debug_projectile_event` observer reports configured birth after visual setup and queued player contact from the actual native ray before damage. It supplies original projectile, shooter, map, player, physics tick and copied hit data. Reentrant pause, replacement, queued or reparented player/map cancels stale damage. Ordinary owners have no observer; Main's damage API, projectile/blast values and visual behavior are retained.

## Acceptance

- Original source failed the native fixture's missing-birth assertions; no parse or script error caused that RED.
- The candidate passed the synthetic native fixture, then current independent Astra correctness and Sol Ponytail reviews.
- Post-review source-native checks passed: exact identity/order, copied dictionary mutation, queued source, pause/replacement/reparent guards, all three difficulty/armor results, no-observer parity, marrow visual-complete birth, repeated queued-step rejection and owner teardown.
- Affected native damage-geometry and combat-expansion checks passed. These cover actual swept collision, armor, blasts, infighting, lifetime, pickup/cooldown, persistence and map cleanup.
- The existing earned Processional entry can now be reused without quitting its owner. Its route, assertions and budgets are unchanged; independent helper reviews and native entry checks passed.

The observation fixture manually steps a synthetic native arena. It does not establish a complete earned caster route, packed-app attribution, release-template gating, physical input, audio quality or performance. Observers are trusted source-debug test code; copied dictionaries preserve Node identity and do not sandbox arbitrary synchronous Node destruction.

## Integration and rollback

The production change is confined to `game/scripts/projectile.gd`. The non-quitting entry extraction and parser contract prepare later campaign fixtures; no map, score, art or live player save changes. Remove the observer sites/helper to restore the previous production path. The shipped private prerelease is not rebuilt by this source milestone.
