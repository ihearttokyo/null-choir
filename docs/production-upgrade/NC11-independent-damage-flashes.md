# Independent damage-flash comfort

Settings now exposes Reduced damage flashes independently of Camera shake. The HUD uses the existing capped flash alpha with factors1.0/0.6 from this new choice; camera motion no longer selects flash intensity. The default remains full intensity. Turning camera shake off in a legacy file does not implicitly enable the new option.

Preferences serialize version2. Complete version1 documents retain all seven old option values and keyboard/mouse/gamepad bindings, adding only the false reduced-flash default. Older version1 documents missing survey retain the existing additive survey migration. Version2 requires all eight options and every action. Unknown, malformed, nonfinite, out-of-range and incomplete documents reject before live mutation. Loading never rewrites the saved file; normal Settings changes use the existing atomic save path.

The new native fixture checks migrated chords/device families, caller/export aliases, inclusive range bounds, invalid documents, unchanged disk bytes, real Settings checkbox persistence/restart and16 actual HUD-alpha cases across both independent choices. The original preferences suite is unchanged. Its survey companion now constructs an actual seven-option version1 legacy document rather than mislabeling current version2 output.

The first round-trip assertion incorrectly compared integer binding codes with JSON-decoded floats. Both complete primitive documents are now compared in decoded representation; production validation was not loosened. Independent review also caught JSON masking a rejected NaN-to-null caller mutation. Explicit float/NaN/signed-infinity identity assertions detect that mutation while preserving the full document and live-state assertions. A first repair failed on the intentionally malformed options Array; its guarded replacement passes. All failures remain retained.

```sh
python3 tools/check_game.py tests/test_damage_flash_preferences.gd tests/test_preferences.gd tests/test_survey.gd
```

Thirteen assembled native scripts pass after independent correctness/Ponytail closure. Reintroducing camera-shake coupling, accepting an incomplete v2 document, or mutating a rejected NaN to null fails the intended native assertions.

Native headless state/policy tests cannot certify flash comfort, final pixels, physical controls or a standalone app. Defaults, camera shake, sensitivity, FOV, combat, campaign data, art and audio are otherwise unchanged. Rollback reverts this focused change; retain any version2 user file before testing an older build, because the old reader rejects version2.
