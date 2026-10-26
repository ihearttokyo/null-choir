# Immutable Intake revision-one baseline

Captured before the authored gallery revision2. SHA256SUMS.txt binds the exact
JSON and migration/schema/layout source bytes. These are historical fixtures,
not runtime replacements; do not update their expected hashes to accept v2.
Runtime `scripts/floors_v1.gd` retains this JSON's terrain-only fields so the
existing save version2 can distinguish saved floor1 from original floor0.

Revision2 adds a three-tile-wide ramped crossing from the bell chamber to a
four-metre upper west-nave gallery. Its north/south ramps and retained lower
nave provide alternate traversal and cross-height combat sightlines. Two
existing cover models move onto the upper landing; enemies/resources/seals
retain their identities, roles, counts and authored cells. The bell loop's
explicit route now includes the new upper connection.

Static independent triangle-route tests are not native navigation, capsule,
collision/cover, earned seal-order, visual, frame-time or standalone acceptance.
The native migration test exercises both 0->2 and 1->2 without writing files;
it must run separately. Native traversal must check the bridge, both ramps,
landing cover clearance and lower return with actual player/enemy capsules.
