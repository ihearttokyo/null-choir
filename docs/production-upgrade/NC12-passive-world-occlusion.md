# Passive world occlusion

Passive pickups and checkpoints now require a clear world ray to their tangible marker envelope, in addition to the unchanged1.4m/3.2m proximity and existing key requirements. One shared helper uses the actual small imported mesh bounds, two usable player-capsule origins and two floor-body heights. It rejects paused, dead, pending, stale or retired participants before querying. No global cache, scene ownership or resource/save policy changed.

The native regression reproduced both pickup and checkpoint activation across a thin registered wall. Current paired cases preserve resources, story, markers, actor images and disk bytes while blocked; the same pose grants or saves once after removal. A second wall sits0.02m before the nearest tangible mesh edge. Full and legacy-over-cap supplies remain available, and a partial supply grants only remaining capacity.

The authored entry-ammo center lies partly inside a low scenery base. A decorative-center ray would reject it. The helper instead reaches the exposed nearest part of the actual compact marker envelope. Both the staged retained west-aisle pose and the real virtual-input entry walk/combat/west-seal fixtures remain green, with their original resources and deadlines.

The first extended fixture held Main processing before entry into the tree, where native callback registration re-enabled it. An unblocked wait therefore collected the marker before the next wall. Holding after entry, with an explicit assertion, repairs only that fixture. The original production baseline still fails both blocked assertions under the corrected hold. No assertion was weakened.

Independent correctness and Ponytail reviews are clean. Twelve affected assembled source-native scripts pass, including earned routes, interaction, story, encounters, marker purposes, facing recovery, damage-flash preferences and the two-frame Settings/Controls/difficulty regressions.

```sh
python3 tools/check_game.py tests/test_passive_trigger_occlusion.gd tests/test_intake_west_seal.gd
```

This is bounded mesh-envelope visibility, not exact-triangle contact or proof of wall incidence in every authored map. Synthetic paired tests hold actors and explicitly invoke the production proximity callback; earned-route checks run native gameplay automatically under virtual actions and scripted aim. Human controls, GPU/performance and the current standalone app remain unverified. Rollback reverts this helper, its two guards and the new fixture/document; existing saves and maps remain unchanged.
