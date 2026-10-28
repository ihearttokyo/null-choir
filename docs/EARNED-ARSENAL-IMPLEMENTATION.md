# Earned arsenal — implementation contract

**Status: implementation integrated in the v0.096 source candidate; not native-qualified, shipped or balance-qualified.** This consolidated increment includes the merged v0.095 wardens/walls rather than releasing that older intermediate separately. It implements the 27 October expansion in `MAJOR-UPGRADE-PLAN-2026-10-26.md`. The iteration ledger has allocated96; proposed reduced G/O budgets below remain proposals, while the first implemented finite registry conserves original authored supplies for validation. No new campaign, art repaint, reload system, universal loot table, paid tool or heavy bake is required.

The source candidate now consumes eight textured, editable glTF/GLB healing-machine families at 32 separately authored floor-bolted service points. Level owns persistent fixed-mesh collision before navigation/safe spawn; refresh updates real stock and gauge geometry without rebuilding fixtures. The actual visible control and its source-bound front anchor own facing/line-of-sight eligibility, never an arbitrary scenery point. The separate placement map reauthors poses while preserving finite IDs, capacities, requirements, legacy aliases, resource envelopes and transaction rules. Source review and portable source tests pass; actual 4.7.2 import, native collision/Space/save behavior and 640×360 full/partial/empty readability remain unrun. The reference is not a runtime substitute, Pro output, a Blender master or native8K art. The existing predeclared gameplay rubric and unrounded 9.2 stopping rule remain unchanged; source checks do not supply that intended-use score.

## 1. Measured starting point

Read directly from current `player.gd`, `projectile.gd`, `campaign.gd`, `preferences.gd` and the eight `game/data/0*.json` files. Counts are static authored counts, **not actual collected quantities, reachable native proof, sustained damage or human difficulty measurements**. Summoned crawlers are excluded; there are at most six births per summoner, two living per owner/four globally.

`R/S/T/M/C` below means Rivet rounds / Scatter shells / sawTooth rounds / Marrow rounds / Choir charges. Ammo columns exclude amounts bundled with weapon grants. Health/armor are summed units, not useful recovery (caps/waste matter).

| Chapter | Actors | Floor records ammo / weapon / health / armor | Floor ammo R/S/T/M/C | Health / armor | Weapon grant inventory + bundled ammo |
|---|---:|---|---|---|---|
| Intake | 23 | 4 / 0 / 4 / 1 | 170/0/0/0/0 | 120/40 | none |
| Foundry | 23 | 6 / 0 / 4 / 2 | 325/0/0/0/0 | 120/95 | none |
| Processional | 26 | 7 / 1 / 4 / 2 | 135/54/0/0/0 | 115/120 | Scatter +16 |
| Reliquary | 31 | 13 / 1 / 7 / 4 | 340/52/0/0/0 | 210/190 | Scatter +16 |
| Nursery | 29 | 12 / 2 / 4 / 4 | 300/44/60/0/0 | 130/200 | Scatter +16; Repeater +60 |
| Ossuary | 27 | 12 / 2 / 4 / 2 | 300/44/60/8/0 | 105/65 | Scatter +0; Launcher +8 |
| Inversion | 30 | 13 / 2 / 4 / 2 | 365/44/75/8/30 | 115/70 | Scatter +0; Disruptor +30 |
| Heart | 33 | 14 / 2 / 4 / 2 | 380/48/90/10/75 | 125/80 | Scatter +0; Launcher +8 |

Totals: **222 actors; 145 floor pickup records = 81 ammo +10 weapons +35 health +19 armor**. Existing new-campaign resources are Impact+Rivet owned, 90 Rivet rounds, 100 health/0 armor; chapter transitions carry resources rather than grant another 90 rounds. Armor currently caps200; health100. Weapon capacities: R180/S32/T240/M24/C120. The bundled supplies above are additional to floor ammo; do not double-count or silently lose them in migration.

| Role | Intake | Foundry | Processional | Reliquary | Nursery | Ossuary | Inversion | Heart | Total |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Crawler |13|12|11|13|12|11|12|14|98|
| Worker |10|11|11|14|10|10|12|12|90|
| Caster |0|0|4|4|3|3|3|3|20|
| Brute |0|0|0|0|1|1|1|1|4|
| Guardian |0|0|0|0|1|1|1|1|4|
| Summoner |0|0|0|0|1|1|1|1|4|
| Nursery Warden / Choir Avatar |0/0|0/0|0/0|0/0|1/0|0/0|0/0|0/1|1/1|

All16 seal bearers and eight named door wardens are promotions of these existing actors. Preserve their IDs, required seals, actual corpse-origin drop state, independent route order, and earned legacy exit exemptions. Do not repin historical source-art/native receipts as qualification of changed gameplay.

## 2. Six distinct capabilities, explicit bounds

Preserve baseline damage/cadence unless a named combat counterexample justifies rebalance. Cosmetic seeds never change coverage; physical variation uses the actual damage query. Retain pause/map/death/reentrancy fences, per-weapon cooldown, one accepted shot/tick, dry-fire fallback and no reload.

| Weapon | Actual model and baseline | Proposed variation / presentation | Tactical capability and cost |
|---|---|---|---|
| Impact Tool | Instant contact,2.7m;28 damage;0.36s | Two seeded cosmetic contact accents; no fake travel or aim shift. | Free fallback, risky approach; no splash/penetration or universal melee-solvency claim. |
| Rivet Pistol | Hitscan22;0.21s;140m hard/useful;1 round | Keep accepted v5 alignment and zero spread. Seed flash/fragment variants, identical ray; tracer does not delay damage. | Precise core; one target, actual clutch contact; no universal headshot/armor bypass. |
| Scattergun | Seven hitscan pellets×15 to8m, falloff to20% at32m;0.7s;1 shell | Center pellet fixed; outer pattern deterministic rotation±3°, jitter≤0.003rad; cap outer tangent radius0.070. Footprint grows with distance. Broad plume/actual pellet impacts. | Close commitment;105 nominal only if all pellets land. No wall penetration or per-pellet stagger-lock refresh. |
| Sawtooth Repeater | Hitscan16;0.085s;140m hard/24m useful;1 round | Existing spread disk +0.004/shot, cap tangent-radius0.07 (~4°), decay0.06/s; local seeded sequence replaces global randf. Cold first shot exact; actual-endpoint traces. | Fast suppression, lower damage/round and burst discipline; no splash/penetration. |
| Marrow Launcher | Swept projectile24m/s×4s→96m;110 direct;4m LOS radial falloff;0.8s;1 round | Keep speed/aim fixed initially; seeded trail/impact variation. Physical sweep/blast LOS authoritative; direct victim not hit twice. | Rare area denial/leading; conditional collateral, cover and self-damage. Not110 to every nearby target. |
| Choir Disruptor | Hitscan40 per actor;up to3 distinct victims/24m;0.16s;1 charge | Straight aim; seeded finite phase/impact segments stop at actual wall. Transparent texels do not consume slots. | Rare alignment capability;120 nominal only with3 valid victims. Here pellets=3 means target limit, not three directions. |

Gameplay jitter is deliberately zero where precision/leading defines the weapon. Saved accepted-shot counters advance only on accepted fire, not dry-fire/pause; never drive loot. Existing saves reset transient combat; persisting in-flight projectiles is a separate decision, not a way to duplicate shots.

Effects stay in the existing bounded AmmoVisuals pool: narrow Rivet streak, broad Scatter plume, short Repeater flashes, traveling Marrow trail, finite Choir segments and material-appropriate impacts. Reuse accepted weapon art; preserve pistol registration. Respect reduced flashes/motion; effects never enlarge damage, advertise false splash or reveal through walls.

## 3. Authored corpse equipment, not universal random confetti

Rewards are finite registry grants owned by authored carrier/chapter IDs. Death, including infighting, creates each once at reachable corpse support. Role eligibility is not a universal guarantee. Difficulty chooses fixed authored quantities. Prefer explicit optional grants; if chance is retained, hash campaign seed+chapter+carrier+registry revision so reload cannot reroll.

| Role | Eligible carried rewards | Required restrictions |
|---|---|---|
| Crawler | Normally none; explicitly authored courier may carry a visible stolen pack | No default bullets/weapon/health from every animal. Never rely on randomly rewarded crawler for route minimum. Summoned crawlers grant **nothing** (no infinite ammo/armor farms). |
| Worker | Rivet packs; chapter-specific tagged weapon/equipment carrier may carry Scatter/Repeater or their magazines | Most guaranteed core supplies come from designated Workers; register each bundle and show a plausible carried/corpse marker. Not every Worker carries every ammo family. |
| Caster | Sparse Choir resonator charges only once that capability is introduced; otherwise none | No generic firearm/health reward; materialize actual finite charge count, not full capacity. |
| Brute | Optional armor fragments or explicit carried heavy magazine; seal bearer always drops its seal | No routine healing. Heavy ammunition only in chapters that have introduced that weapon. |
| Guardian | Armor and sparse Marrow/Choir equipment as explicitly authored | Front armor defense must be included in supply-cost tests; no free refill on partially collected drop or save. |
| Summoner | One finite ritual cache on its own death, restricted to chapter progression | Its adds have no rewards; no reward repeated per summon cycle. |
| Nursery Warden | Guaranteed seal-independent post-fight equipment/cache as authored; no vital ammo credited *before* this boss dies | Already mandatory exit boss; cannot pay for its own fight. No automatic health refill/revive. |
| Choir Avatar | Optional final corpse reward, otherwise none | Post-ending supply is not counted toward completion solvency. |
| Named seal/door champion overlay | Seal guarantee +the carrier's explicitly budgeted equipment grant | Seal is never a probabilistic item, never exchanged for ammo, and its one-life/drop/save rules remain independent of equipment collection. |

Keep Impact+Rivet initially owned. Convert each weapon pickup into a named corpse carrier: separate unlock/ammo grants preserve useful ammo remainder if the weapon is already owned. Proposed first Scatter carrier: `processional_enemy_13`, entry-side Worker with no seal prerequisite. Assign later recovery copies through route analysis, **not nearest-enemy selection**: Nursery21 requires Ivory, Nursery18 Blood; neither alone is an order-independent early Repeater source. Similar dependencies exist at Launcher/Disruptor approaches. Required equipment must precede its dependent fight.

Armor is not named in the user's mandatory floor-removal list, but retain no accidental ambiguity: **proposal** is to migrate the existing19 armor records into authored Worker/Brute/Guardian equipment too, with the same tombstone/partial-cap rules. If armor stays as world fixtures instead, explicitly decide that before authoring; do not count both versions.

## 4. Proposed economy, guaranteed prefixes before optional totals

These are **Relentless authoring targets for first tests**, not measured sustainable balance. `G+O` = guaranteed earned quantity on designated nonoptional carriers +finite optional earned quantity; neither is granted at entry. Preserve existing carryover/caps and the one campaign-start90 Rivet grant. Totals include weapon-bundle ammo, unlike the measured floor-only column above.

| Chapter | R G+O | S G+O | T G+O | M G+O | C G+O | Healing G+O units |
|---|---:|---:|---:|---:|---:|---:|
| Intake |140+30|0|0|0|0|90+30|
| Foundry |190+60|0|0|0|0|90+30|
| Processional |140+40|20+12|0|0|0|85+30|
| Reliquary |190+80|24+12|0|0|0|150+60|
| Nursery |220+80|24+12|48+24|0|0|100+30|
| Ossuary |220+90|20+12|48+24|4+2|0|80+25|
| Inversion |240+95|20+12|60+24|4+2|6+3|85+30|
| Heart |260+100|24+16|72+24|6+2|9+3|95+30|

Compare useful damage **and capability**, not raw ammo counts. Initial modeling yields: R12.1/round (22×55% hits), S45/shell (miss/falloff model), T7.2/round (16×45%), M66/round against one target (110×60%), C22/charge against one target (40×55%). These are assumed workloads, not measurements. Replace with actual near/mid/far results; report armor, overkill, cadence, cover/risk and collateral separately. Optional penetration/splash cannot count as guaranteed damage.

For every chapter author **two schedules**, Blood→Ivory and Ivory→Blood, using encounter IDs and existing trigger/door conditions. Registry must record each grant's source encounter and the earliest required fights it can fund. Prefix acceptance:

1. Guarantee an independently reachable ordinary-carrier prefix before either first bearer. Use actual carryover, not full capacity; a required victim's own corpse cannot fund its fight. Impact is a fallback, not proof every boss is safely meleeable.
2. Initial test reserves:40 useful Rivet rounds before first bearer,30 before second/door progression, **plus prefix fighting cost**. For larger mandatory fights use the larger `ceil(required_HP/conservative_core_yield)`, including actual armor. Author encounter-ID allocations at entry, both loops, returns and pre-final; optional supplies never fill a guaranteed deficit.
3. Keep both route orders' equipment/supply independent; no single-seal-only new gun dependency. Difficulty ammo G/O multipliers initially Merciful1.00/Relentless1.00/Terminal1.35, rounding each grant upward, versus current HP.85/1/1.3. Healing proposal1/1/1.25 versus incoming damage.7/1/1.4: **untested tuning**, not an equivalence claim.
4. Test both orders ×all difficulties with zero optional rewards, realistic misses, low carryover and partial-cap pickups. Fix a prefix deficit with earlier earned supplies or a reviewed encounter adjustment, never free floor refills, seed retries or optimistic damage.

## 5. Space healing and walk-over loot are different transactions

**Loot:** sweep last accepted→new player position after physics, not endpoint-only overlap. Require same physical surface and world/closed-door obstruction checks; no wall/floor magnetism. Reset segments on teleport, load, checkpoint and map replacement. Collect automatically, never E/Space. Transfer only `min(remaining, capacity-current)`; full capacity leaves the item. Unlock and ammo are separate. Duplicate/deferred callbacks observe committed remainder and do nothing.

**Healing:** contextual `use_asset`, Space/controller equivalent. One provenance-valid rising edge, current scene, reach/view/LOS; heal `min(missing_health, remaining)` and decrement atomically. Full health consumes nothing. No cooldown regenerates stock. Checkpoint restoration restores its **whole envelope**, including health and station depletion; never combine old health with newly refilled stations.

Player/Preferences currently have **no jump action/Space gameplay default**. Add use, not jump. Retain E records/doors initially or explicitly arbitrate one deliberate-use consumer per press. GamepadA/E bindings must not vanish. Preferences require exact action sets (version3): additive version4 migration preserves all prior bindings and adds only use_asset. Held Space on Continue, key echo, pause/focus loss, rebind and controller disconnect need release fences. Prompts use actual binding text. Walk-over pickup is independent of these provenance gates.

Replace35 health-floor records with finite, identifiable reservoirs/control fixtures, not upright potion markers. Start with four stations/chapter (entry/junction, each loop, pre-final); combine Reliquary's seven old grants without duplicating units. Preserve measured health totals initially, split G/O as above. Existing hero anchors: Intake skin_bell/siphon_heart; Foundry vertebral_furnace/marrow_crucible; Processional walking_bone_organ/ossified_palanquin; Reliquary face_halo/memory_wheel; Nursery gestation_engine/seed_orrery; Ossuary bone_mandala/rib_bridge; Inversion surgical_cradle/tilted_gyroscope; Heart mouth_restraint/pulse_mandala. These are existing anchors, **not verified interaction surfaces**: author accessible offsets/visible reservoirs, remaining/depleted states and Space prompts. Preserve story controls and seal gates.

## 6. Per-envelope typed data and legacy migration

Use one versioned earned-supply registry and one finite save extension, not new objects serialized into saves. Retain current campaign/terrain versions unless a deliberate schema bump is needed. Every structure below belongs independently to **current, checkpoint and level_start**; validate all three before publishing any live state.

**Content registry:** explicit chapter/revision/grant/carrier IDs; kind/weapon0..5/amount; per-difficulty quantities; guarantee/optional flag; encounter prefix; old pickup aliases; station anchors/capacities. Reject duplicate IDs/aliases, unknown references, circular prerequisites, bad quantities or summoned sources. Bound counts to authored maxima.

**Modern state**, e.g. `earned_supply.version=1`:

- `loot_drops`: unique `{grant_id, position:[3], remaining:int>0}`; carrier/type/weapon/max come from registry. Carrier must be validated defeated. Exhausted grants move to claims.
- `loot_claimed`: unique registry IDs, not arbitrary removed IDs. Separate weapon-unlock/ammo grants. Every dead carrier's grants are pending or claimed; living carriers have neither except exact legacy linkage.
- `healing_remaining`: every known station once, integer0..capacity. Never infer depletion from current health; preserve existing seal_drops/legacy_exit_wardens.
- Optional shot_sequence[6]/campaign seed: finite integer bounds and absence migration; loot does not depend on shot count. Reject unknown/extra fields, unsupported revisions, invalid physical-layer positions and contradictory claims. Save partial remainder exactly; never recreate full stock on load.

**Retired pickup tombstones:** before removing runtime pickups, freeze the exact145 current IDs in a chapter-scoped legacy registry (original kind/weapon/amount/mapSHA). Permit only these exact tombstones plus valid current actor/door/interaction/encounter/summon IDs in Campaign.removed; never accept arbitrary strings or a `loot:*` prefix. Terrain migration keeps immutable original floors, but joins economy metadata to the current chapter rather than guessing it from old terrain data.

**Legacy field absence** is the sole migration branch:

1. Validate original resources/IDs/actors; preserve ammo, weapons, health, armor, seals, defeated actors and existing legacy exit access. No reset/refill or invented enemy defeat.
2. Removed old ammo/weapon/armor ID means its exact linked entitlement was claimed: do not subtract inventory or award it again. Owning a gun does not imply every later recovery copy's ammo was collected.
3. Uncollected old grant: living new carrier→unborn; already-dead carrier→one finite replacement at explicit validated legacy anchor (unknown corpse), not resurrection. A migrated preclaimed grant on a living carrier requires exact old tombstone linkage, not a general exception.
4. Consumed old health aliases deplete their mapped station by each original amount once, against its exact combined capacity; keep already-healed current health. No healing from tombstones, duplicate aliases or invented partial legacy claims.
5. Migrate each envelope privately, validate the full image, publish atomically. Malformed checkpoint/start rejects without changing current/user files. Normalized resave/reload is idempotent.

## 7. Clean ownership and immediate implementation order

One integration owner: Main/Enemy/Campaign/schema, eight levelJSON **supply/healing fields only**, registry/module and state tests; owns death materialization, partial pickup/migration, coordinates existing seals. No competing writers to these fields.

Weapons worker: Player/Projectile/AmmoVisuals/effect resources and ballistics tests; exposes accepted-shot/physical sweep data, never mutates loot. Input/UI worker: Preferences/HUD/Survey and input tests; agree `request_use_asset` and `{visible,position,remaining,binding}` with integration owner. Level fixture affordances need a small agreed adapter; walls/lighting remain their owners'. Parent owns versioning/source composite/serialized native grants/release. Independent reviewer receives exact code and actual intended-use evidence, not an author's self-assessment.

Implement in this order: (1) freeze current counts/legacyID map and failing fixtures; (2) registry+all-envelope codec/migration; (3) death materialization +swept walk-over partial transaction +Space finite healing; (4) migrate authored floor supply/weapon progression and author both-order prefix schedules; (5) deterministic weapon/effect differentiation; (6) independent review, affected native tests/actual gameplay evidence and matching package. No source-only plan/table is the delivered feature.

**Must-fail controls:** foreign/duplicate carrier/grant/station/tombstone; living drop; repeated death/collection; claimed+pending or missing sole reward; bad remainder/capacity; owned weapon+full ammo split; malformed current/checkpoint/start independently; legacy tombstone/defeated-uncollected/idempotent migration; summon farming/seed reroll; malformed preference migration; held Space/echo/controller reconnect or one press using two assets; swept fast pickup versus wall/gate/stacked Ossuary floors; teleport sweep/stale scene callback; spread cap/actual endpoints/transparent-hole penetration/finite victim count; direct+splash double hit; reduced effects changing damage. Run both orders×three difficulties, zero optional supply and deterministic misses. Log accepted damage, collected/wasted/remaining ammo, healing, inputs and resources per encounter. Human feel and sustained performance remain separate. Retain wardens/walls/Worker/pistol/gate/music/terrain regressions.
