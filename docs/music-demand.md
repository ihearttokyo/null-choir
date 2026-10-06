# Campaign sample-request audit

The audit reads the eight original MIDI files and the SoundFont preset metadata without reading sample PCM. It checks that every authored note selects at least one sample layer and records each selected layer separately. Two mono samples selected by one note request two logical voices; a stereo-linked secondary stream is counted separately.

This tool supplies source evidence for R16. It leaves the runtime, songs and 96-slot voice pool unchanged. The fixed pool contains linked player nodes even when a score selects only mono samples.

## What the report proves

The report records actual MIDI identities, metadata identity and relevant runtime-source identities. It describes the supported campaign input grammar and fails on unsupported or malformed inputs. SoundFont metadata identity is not a hash of the full sample bank.

The cumulative request ceiling retains every selected layer until the end-of-score loop reset. It deliberately ignores earlier envelope and sample stops. This is a conservative ceiling for one playback epoch, not a measured concurrent peak or a recommendation for pool size. Drum note-offs do not determine native sample lifetimes. A tighter release-tail estimate requires transport, mixer and playback-completion evidence.

## Held acceptance

Native occupancy, stolen-note checks, captured-output parity, listening feedback and startup-memory measurements remain unverified. The report keeps `native_peak` and `captured_output_parity` null, `no_steal_verified` false and `pool_reduction_authorized` false. It cannot close R16 or authorize a game/app rebuild, adoption or promotion. Native engine and GUI validation require their existing clearance.

## Run and test

From the project directory, analyze a complete resident checkout:

```sh
python3 -B tools/music_demand.py --root /path/to/resident/null-choir
python3 -B -m unittest discover -s tests -p test_music_demand.py -v
```

The CLI writes JSON to stdout and never changes scores or the bank. The six built-in runtime-source pins, including the MIDI decoder, are always checked. No external manifest is required. Keep input files resident. This command does not grant cloud hydration or native engine clearance.
