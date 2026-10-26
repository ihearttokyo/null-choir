# Live pixel Sound Test

Source integrated; the matching packaged release is still pending.

Sound Test now draws an original little mechanical music garden live: a drum
beetle winds up and strikes, a spring creature compresses and launches a block,
and a bird hops, flaps and catches it. A connected pipe garden replaces the old
smooth cathedral visualizer. The editable canvas shader generates the characters,
scenery and moving patterns; it does not display an animated reference picture.
Its crisp pixel grid uses sixteen opaque colors, without smooth gradients or
bloom. Garden, Star Parade and Orbit Play retain the three existing style indices
and the same cast, with seeded stars and orbit variations.

## Motion and music are different inputs

The decorative performance follows the owned Music player's playback position,
with ten discrete pose steps per playback second. Real measured Music-bus peak
and low/mid/high magnitudes separately influence bounded visual tiers. The passive
1024-point analyzer measures 40–250, 250–2000 and 2000–12000 Hz; it does not infer
beats, instruments or RMS. Music and Master gains are applied once to raw
frequency magnitudes. No second audio player or microphone is used.

Normal pause holds the image. Reduced motion selects a complete neutral still,
including when paused. Mute clears measured response; muted playback can still
advance decorative animation. Closing the panel stops its owned preview, hides
the actual art, suspends processing and removes only its exact analyzer effect.
Track replacement and external playback takeover cannot retain the old signal.
Transport, volume, focus and the existing preference boundary remain shared.

## Sources and qualification

- Runtime and editable art: `game/ui/resonance/resonance.gdshader`.
- Music ownership and analysis: `game/ui/resonance/sound_test.gd`.
- Retained art-direction reference and prompt:
  `source/art/references/pixel-music-garden-20261027.*`.
- Focused native tests: `test_sound_test_spectrum`,
  `test_sound_test_procedural_art`, `test_sound_test_motion_signal`,
  `test_sound_test` and `test_sound_test_menu`.

Independent intended-use review accepted the exact combined host and artwork.
Native Dummy-mixer tests separately exercised generated tones through the actual
analyzer. A muted actual Music/SoundTest consumer produced sixteen timestamped
animation samples, exact pause/reduced holds, hidden retirement and one portrait
neutral view. Those samples are not a full-rate performance capture. Listening,
musical fit, physical controls, portrait live motion and sustained performance
remain outside that evidence. A packaged build must be verified before this
feature is advertised as released.

The characters, code and reference are original NULL CHOIR work. Tyrian supplied
the requested playful retro direction; no Tyrian assets or code were copied.
