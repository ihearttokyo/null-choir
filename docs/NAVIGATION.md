# Navigation rebuilds

`navigation_routes.gd` owns current-level geometry, native maps and bounded route queries. Enemy movement capsules, source collision geometry, role order, clearance, query limits and map-readiness witnesses are unchanged.

Baking uses Godot's native asynchronous API. Each owner retains one outstanding mesh/source/revision record and polls completion on later process ticks. A door change disables stale routes immediately; a retired result cannot publish. Source parsing stays on the main thread. Teardown drops local ownership; the engine completes its resource-owned work without a callback retaining a freed Node.

## Verification

On Apple M4 with official Godot 4.7.2, the new native lifecycle fixture passes 112 assertions: deferred publication, actual busy-job retirement, door changes, current-level replacement, teardown/reconfigure/free, resource/RID release, capsule clearance and query limits. The effective installed threading setting is `navigation/baking/thread_model/baking_use_multiple_threads`; its assertion fails closed.

Four affected native suites pass, including the eight-map geometry/varied-route diagnostic. Fixture completion waits include both queued and outstanding bakes, with the existing time bounds retained.

One twelve-second Mobile/Metal diagnostic per arm kept the same Intake art, 23 actors, seed, input script, opened door and auto-aim setting. Synchronous role bakes took 52.5–54.4 ms on the main thread. Async dispatch took 16–44 µs; parsing took 3.82–3.88 ms in the sync arm and 3.92–4.24 ms in the async arm. The largest observed async navigation process call was 4.243 ms. Both arms reached a peak of 2,023 draw calls.

This isolates a blocking component; it does not prove overall FPS gains. Wall-clock input and AI can diverge, cache state was not controlled, and the reported display was 60 Hz. The observed maximum frame intervals were 87.873 ms for sync and 198.734 ms for async; other frame hitches remain. The 120 FPS target, the reported one-second freeze, physical-input campaign, listening and packed-app acceptance remain open. These diagnostics captured text counters only.

Rollback is the prior synchronous owner; the new behavioral regression intentionally fails there before any new-only state is accessed.

Run the focused native checks with:

```sh
python3 tools/check_game.py --timeout 90 tests/test_navigation_async_lifecycle.gd tests/test_navigation_routes.gd tests/test_native_navigation_regressions.gd tests/test_native_enemy_route.gd tests/test_navigation_campaign_geometry.gd
```
