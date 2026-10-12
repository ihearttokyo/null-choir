# Physics-owned export verification

The standalone Apple Silicon app passed its packaged headless workflow, including all eight maps and baked Metal caches. Running that same workflow with Mobile/Metal failed `scattergun_fire`. The verifier called `Player.fire()` after a physics-frame signal; that signal alone did not guarantee a physics callback in both schedules. Normal OS-injected pistol input worked in the dedicated game window. This finding concerns the verifier, not permission to weaken the production firing guard.

A one-shot native node now calls each verification shot from `_physics_process`. It captures the current player, rejects replacement or missing identities, returns the actual fire result and stops processing. All original ammunition, cooldown and flash assertions remain intact. Gameplay input and `Player.fire()` are unchanged.

The focused test stamps a real player-probe physics callback before the driver. A signal-only substitute fails the original firing assertion; the callback-owned driver passes. Replacement and missing-player cases also pass. Earlier test-harness type errors are retained as execution failures, not regression evidence.

Independent correctness and Ponytail reviews are clean. A headless source replay using the retained, real GPU-baked cache passes every full-workflow check, including all eight maps and late weapons. It is source evidence, despite the workflow’s reused “packaged” log labels. A corrected standalone GPU run remains outstanding after the bounded game-window session ended. Neither source checks nor the previous headless app pass establishes this corrected app's GPU acceptance, performance, listening or finished-art quality.

```sh
python3 tools/check_game.py tests/test_export_fire_tick.gd
```

Rollback reverts the verification helper/call sites and omits its focused test. No save, asset, map, preference or normal gameplay behavior changes.
