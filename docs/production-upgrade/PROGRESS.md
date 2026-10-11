# Production upgrade progress

## NC-01: heading-independent movement

The shared player callback now approaches desired planar velocity with one vector step. Speed remains9m/s, acceleration remains50m/s², and Input.get_vector(), native capsule, gravity, floor snap and mouse look are unchanged. The native fixture exercises135 forward/strafe/diagonal start/full-reversal/stop cases at five yaws and three action strengths. Each tick checks an independent scalar distance budget, actual displacement and settled floor contact.

The old component-axis source fails the retained native regression. Omitting move_and_slide() also fails, so a stationary player cannot pass by reporting a plausible velocity. A low analog speed can stop in one tick without displacement; that valid case is preserved. Two independent-review fixture findings were fixed before broader validation.

Run from the project root:

```sh
python3 tools/check_game.py tests/test_movement_response.gd
```

The retained parent trials use official Godot4.7.2, headless/Dummy audio and a fixed60 simulation. They establish source-native behavior under virtual input, not physical-controller comfort, GPU presentation or a packaged playthrough. Broader collision/traversal and current-head review receipts remain tracked outside Git.

## Existing independent candidates

PR35 retains the sharper-world/pixel-HUD experiment; no competing renderer patch was made. The separately reviewed Nursery source candidate preserves the original source and other102 asset entries. Its reference-richness, in-game transparency and performance remain separate acceptance checks. All prior releases, source originals and failed experiments are retained.

## Continuation

Next implement NC-02 through the actual input, readiness, accepted-shot-age and HUD callers after freezing its lifecycle tests. Preserve all six weapon behaviors, dry fallback, stale/reentrant callback guards and asynchronous menu/placement regressions. All14 spec contracts and section19 gates remain in scope. Source progress does not complete the full campaign/app goal.
