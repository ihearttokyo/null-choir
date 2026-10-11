# Export art contract

The export verifier required one extra containment capsule in every map. Current level construction places capsules only from authored scenery; those counts are 8/12/9/12/11/8/10/12. The actual source-native export workflow reported all eight capsule checks false. Its separate headless Metal-cache failure remains enforced.

One art evaluator now retains every authored hero/scenery count and the shared ribbed-wall/conduit minima, without the phantom capsule increment. It also checks all remaining purpose-specific markers: exact family counts, imported resource paths, unique IDs, visible ArrayMesh surfaces, anchors, scale/yaw and absence of collision nodes. Removed IDs do not contribute expected markers. The export workflow and regression fixture call the same evaluator; an existing independent purpose oracle checks actual marker geometry.

The native fixture passes all eight maps and 185 initial markers across thirteen art IDs. Counterfactuals reject a dropped instance, unrelated GLB, primitive floor geometry, extra family instance, collision body and missing authored capsule. Restored cases retain campaign data and exact native collision identities; removing a consumed visual marker leaves those bodies intact. No asset, map or save is changed.

Independent correctness and Ponytail reviews are clean. Non-art export checks remain byte-identical. The actual full source workflow now reports only its unchanged Metal-cache failure; no other check fails in that run. This is not a packaged-app pass. Headless tests cannot establish native Metal caches, GPU appearance/performance, physical controls, listening or finished-art fidelity. No cache assertion is bypassed or weakened.

```sh
python3 tools/check_game.py --timeout 90 tests/test_export_art_contract.gd tests/test_marker_purposes.gd
```

Rollback reverts the evaluator, its export call and new fixture/document. Existing art, saves and gameplay are unchanged.
