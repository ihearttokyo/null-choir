# v0.096 movement: pause and input cancellation

The Doom-derived35Hz acceleration/friction/displacement reference remains the movement target. **Pause/focus/menu cancellation is a deliberate Godot/input-safety adaptation:** retain the existing game's `Player.cancel_actions()` behavior, stopping horizontal velocity and resetting the helper's stored momentum and fractional interval. Resume starts a fresh interval; it does not revive pre-menu drift or consume a hidden backlog. This is not a claim of exact Doom pause semantics.

This decision confirms the adaptation already documented in `work/earned-arsenal-prep/MOVEMENT-IMPLEMENTATION-NOTES.md`. It supersedes only the earlier proposal sentence “Pause freezes phase/time” in the retained `DOOM-MOVEMENT-SPEC.md`; that frozen historical file and its original hash remain unchanged. It does not alter active, uninterrupted35Hz motion, contacts, saved campaign resources or release-required fire/use fences.

Acceptance needs an actual source-native trace: establish nonzero motion, release inputs and invoke real pause, verify zero velocity/momentum/fractional phase, resume without commands and verify no stale drift, then establish fresh acceleration. Record observed positions/ticks; static reset code alone is not that trace. No physical human-input/feel or full-campaign claim follows from this check.
