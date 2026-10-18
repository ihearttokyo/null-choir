# Warden native contact observation

## Change

The existing debug-only pre-damage melee callback now includes the Nursery Warden. The callback runs after the native first-collider ray and before damage, while a living victim still owns its collision shape. Existing post-callback map, Player and victim guards remain intact. Damage, difficulty arithmetic and release-build behavior are unchanged.

The nine earned-route helpers carry the new Enemy source hash through their dependency chain. Their behavior is unchanged; every literal dependency comparison was checked against the actual file, rather than only comparing receipts. This prevents an intermediate hash from surviving propagation.

## Retained regression evidence

The original same-tick contact diagnostic reproduced a stale enemy HP ledger and stale Player contact attribution. Synchronous pre-hit observation and consumed contact records passed the three controlled ordering cases. These diagnostics support the source work; the unfinished earned-finale harness is excluded from this slice.

The committed guard fixture uses production Main, Enemy, Campaign, native collision shapes and real release/contact/damage methods. All 17 controlled cases pass:

- A Worker survives at 58 HP; a staged 20-HP Crawler dies once with collision retirement.
- A first-collider enemy intercepts a charge committed toward the Player.
- Three fixed difficulties yield Player HP 85/78/70 and armor 43/40/36 from 100 HP and 50 armor.
- Range, an original map wall and a native empty ray reject contact.
- Two real Enemy physics calls in one rush produce one hit.
- Pause, queued source/victim, reparented victim, replaced/retired map and replaced Player cancel post-callback damage.

The first wall case had an invalid 2.828 m setup, beyond the 2.4 m reach. Aligning only the staged endpoint reduced that distance to 2 m while retaining the original wall, native ray and every assertion. This was a fixture correction, not a production guard defect.

Independent Astra correctness and Sol Ponytail reviews inspected the connected source and retained evidence. Ten affected public native scripts pass, covering existing enemy/melee/projectile behavior, replacement, the six Settings/Controls/difficulty cases during both placement waits, and actor recovery.

Run the focused source check with an isolated user-data environment:

~~~sh
python3 tools/check_game.py tests/test_warden_melee_guards.gd
~~~

## Limits and rollback

These are controlled debug-native checks, not an earned Warden victory, full campaign, physical input, GUI/GPU, heard music or current standalone-app acceptance. Immediate synchronous frees, complete replacement-map adoption and release-binary parity remain outside this fixture. Release parity is supported only by the unchanged debug predicate and damage expression.

The unfinished finale harness remains local and unaccepted. This slice does not change authored maps, art, saves or soundtrack. Reverting the slice restores the prior callback predicate and matching helper pins together.
