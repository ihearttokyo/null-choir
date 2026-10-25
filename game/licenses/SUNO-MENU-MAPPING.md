# Existing Suno recordings reused for menu roles

The title now uses **03 — Processional That Misses a Step**, first selected take,
`audio/title/title-suno.mp3`, 269.4535 seconds, a byte-exact copy of
`audio/suno/processional.mp3`. Completion/progression/interlude
presentation uses **08 — You Were the Containment System**, first selected take,
`audio/title/interlude-suno.mp3`, 299.6135 seconds, a byte-exact copy of
`audio/suno/heart.mp3`.

These are two of the existing eight unique campaign compositions, not additional songs or newly
generated recordings. The authoritative retained selection/encoding provenance is
`source/music/suno/manifest.json`: Suno v6 cue packet generated 2026-10-07,
first-listed takes downloaded 2026-10-15, retained original M4A sources converted
through the documented FFmpeg MP3 route. The existing rights and redistribution
terms are unchanged; this mapping asserts no new clearance.

Runtime SHA-256:
- Processional: `81c5f60d034fb18a900cdb54ebe1d6cb8f43aac81c405e75b07325f9b310897d`
- Heart: `2df85b64edf66df4a0217a610a7ff5afaa6c0a7a92d0a8b70a52cde807a59104`

One native Music player owns title, interlude and gameplay transport. Repeated
requests for the same menu role resume without restarting. Menu cues play once;
entering a campaign level explicitly restores its looping policy. Two byte-exact runtime role copies have distinct resource paths so menu
loop state and cached resource lifetime cannot affect campaign recordings. No
original audio is re-encoded, normalized or overwritten. User volume/mute remain owned
by the existing Music bus.

The former synthesized title cue `audio/title/the-restraint-turns.ogg`, its score,
MIDI and encoding/provenance receipts remain preserved. That cue was generated
from the editable score and GeneralUser-GS bank, **not Suno**; its historical
provenance describes the previous mapping, not the current menu selection.

Track selection here is a reversible implementation choice based on existing cue
identity, not listening approval. No audition, audible-loop, artistic or standalone
acceptance is claimed.
