# Resonance upgrade — preserved, unaccepted prototype

These are exact source snapshots from 2026-10-26, retaining their original relative paths. The enhanced procedural SoundTest art/UI/spectrum implementation is **pending independent acceptance** and is not the default shipped feature. No aesthetic approval, performance, listening or completed-goal claim is made.

The runtime sound_test.gd and resonance.gdshader were restored byte-for-byte from already-released Preview03 commit `a99595a89f0bff0febc2e76bb6bf48053f6e823d`. Current accepted campaign/art/render work can deploy independently while this upgrade continues separately. Do not advertise prototype graphics, new spectrum responsiveness or upgraded accessibility as shipped by that release.

The copied focused tests describe the prototype (some existing baseline tests are included for context); they are not evidence that these features exist in the restored runtime. Release-suite scoping now restores exact released03 versions where those paths existed, and removes only prototype-only GAME copies after verifying this archive byte-for-byte. Prototype assertions remain preserved here; no unrun all-tests pass is claimed. The released baseline `game/tests/test_sound_test.gd` remains unchanged and is byte-identical to the released commit.

`source-manifest.json` binds all copied source bytes and original paths. No original assets, prior source history, test assertions or user data were removed. This folder is authoring/source only, outside the runtime game project. Future integration requires an explicit reviewed feature decision, not automatic promotion.
