# NC08 marker families and shared glyphs

The candidate adds an ivory three-antler/open-diamond seal and four ammunition
families: paired shells, five sawtooth cartridges, a hollow marrow lance and a
choir tuning fork. Blood and rivet models remain unchanged. Weapon cradles gain
one camera-facing identity emblem. All marker children remain visual-only;
authored IDs, placement, scale, yaw, thresholds, inventory and saves are unchanged.

The shared native glyph atlas provides eight purpose symbols, two seals and six
weapons. The HUD retains its textured heart, shield and frame. Weapon/seal glyphs
use full square cells at 32 pixels; unavailable/empty states retain explicit text
as well as tint. Slot backgrounds draw before glyphs. The survey shares these
meanings, preserves discovered-only information and reserves the player arrow's
space. Labels and callout leaders preserve each marker's meaning and location.

## Production evidence

The inspected reference is `source/art/references/marker-identities-v2.png`,
SHA-256 `061ac88b9d4ff2ae70da4b1996cc1f6d4cda92bf05a698d5887159a8fb2475f0`.
Its generated slogans and lore were not adopted.

- Five background Blender jobs produced 153,328 bytes of combined GLBs and
  3,420,403 bytes of editable sources. Native triangles total 2,648.
- All 71 named source parts were reopened, edited and restored without changing
  source files. Native outward-volume and full GLB/BIN checks passed.
- The glyph scene contains 16 collections, 58 outward editable parts and 2,228
  triangles. Its source is 871,476 bytes; PNG and metadata total 8,663 bytes.
- Native glyph diagnostics at 16/24/32 pixels were inspected. The first diagnostic
  script used mismatched render/extraction dimensions; those outputs were rejected
  and retained. Correctly sized replacements are separate evidence.
- Independent source reviews found and closed crossed sweeps, duplicate ring
  seams and inward glyph faces before native production. Surface detail remains
  below the reference's ambition; these are functional candidate assets.
- Native fixtures establish full-cell mappings, font bounds, state text, draw
  ordering, eight-map identity/placement and resource lifetimes. They do not
  establish rendered game pixels or human recognition.
- The original 111 asset entries are unchanged. The candidate inventory contains
  117 assets and 120 exports. Ten required world previews/geometry receipts are
  explicitly delivered despite the general build-directory ignore.
- The principal art check runs complete family validation. Its regression must
  propagate missing/divergent family rejection, not validate entries in isolation.

## Open acceptance and rollback

Actual game-size and 4/8/16-metre recognition, final surface polish, dark/bright
backgrounds, grayscale/color-deficiency diagnostics, GPU performance and the
standalone app remain open. Native small-size rerenders are not Godot downsampling
of the shipped atlas. No final art, campaign or app completion is claimed.

Reverting this piece restores the previous HUD/survey and purpose-only factory.
Retain original sources, references, blood/rivet assets and failed-candidate evidence.
