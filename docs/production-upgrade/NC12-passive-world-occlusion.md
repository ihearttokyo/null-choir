# Passive world occlusion

Passive pickups and checkpoints require a clear world ray to their tangible marker envelope, alongside the unchanged 1.4m/3.2m proximity and key requirements. The helper uses actual compact mesh bounds, two usable player-capsule origins and two floor-body heights. Synthetic thin-wall and near-mesh-edge pairs preserve resources, markers, stories, actor images and save bytes while blocked; the same pose grants or saves once after removal. Full and legacy-over-cap supplies stay available; partial supplies grant only remaining capacity.

The authored entry-ammo center lies partly inside a low scenery base. A decorative-center ray would reject it; the nearest exposed part of its actual mesh envelope remains reachable. The virtual-input entry/combat/west-seal regressions retain their resources and deadlines. The first extended fixture incorrectly held Main processing before tree entry, which re-enabled it. Holding after entry repaired that fixture; the production baseline still failed both blocked assertions.

## Physics ownership correction

Hosted PR48 review identified unsafe direct-space queries from render processing. The existing Player physics callback now publishes the passive scan after firing/observation. Main rejects nonphysics, paused, dead, pending, stale or retired participants before querying; a tick latch precedes mutations, and lifecycle checks follow collection/capture/save callbacks. Render processing retains encounters, music pressure, feedback clocks and HUD redraw, without passive queries or grants. There is no visibility cache, new gameplay timer or Main physics override.

Actual callback cases cover duplicate calls within one tick, resource/pose changes, pause/resume, placement, wrong Player, restart/drain and title-on-collection reentry. Rejecting a nonphysics helper call fails on the baseline. The assembled candidate also passes with the isolated project's separate 3D physics-thread setting read back as true; the project configuration is restored afterward. This establishes source-native callback behavior, not GPU or standalone-app validation.

Thirty staged passive sites across ten fixtures now await a small real Node callback probe. All original 282 assertion/error statements and 41 render calls remain; eleven encounter-only render sites are untouched. Six newly asynchronous callers await their result. The helper verifies staged identities/pose, bounds completion to four physics signals and drains its owned Node. The old Processional fixture reproduces the missing-scattergun assertion; the migrated fixture passes without changing that assertion.

An equivalent actual callback bridge handles the two export-verifier pickup sites. This does not repair the verifier's preexisting nonphysics direct-fire dependency or certify a current app. Native source tests and packaged checks remain distinct.

## Checkpoint failure feedback

Moving checkpoint work into physics exposed a render-order defect: an encounter cue could immediately overwrite a disk-failure warning. Encounter text now preserves an active checkpoint disk-failure message until expiry, without suppressing actors, lights or sounds. The unchanged save-failure regression reproduces the defect and passes the correction. Extra transient cue probes verify activation and expiry, then restore only their own fixture data before canonical save/Continue checks. Their initial unretired synthetic flags failed canonical validation; that failed run is retained.

## Evidence and limits

Independent correctness and Ponytail reviews cover the production boundary, fixture migration and export bridge. The feedback correction has clean independent closure reviews. Twenty-three affected source-native scripts pass, including all ten migrated fixtures, late maps/all difficulties/both seal orders, active bosses, actor recovery and controlled eight-map continuity. Controlled staging and virtual actions do not establish human campaign completion.

```sh
python3 tools/check_game.py --timeout 90 tests/test_passive_trigger_occlusion.gd tests/test_passive_trigger_physics.gd tests/test_save_failure.gd
```

This is bounded mesh-envelope visibility, not exact-triangle contact or every-map wall coverage. Human controls, listening, GPU/performance and the current standalone app remain unverified. Rollback reverts this PR's production helpers/hook, fixture migration and document; saves and map sources are unchanged.
