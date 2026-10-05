"""Actual late-map JSON checks; native art, physics, bosses and pacing remain separate."""
import copy
import json
import math
import sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FILES = dict(zip(("nursery", "ossuary", "inversion", "heart"), ("05_nursery", "06_ossuary", "07_inversion", "08_heart")))
ART = {
    "nursery": ["gestation_engine", "seed_orrery", "bound_gate", "cell_canopy", "tower_cluster", "seven_vessels", "winged_cradle"],
    "ossuary": ["rib_bridge", "bone_mandala", "bound_gate", "cell_archive", "tower_cluster", "seven_reservoirs", "winged_sarcophagus"],
    "inversion": ["surgical_cradle", "tilted_gyroscope", "bound_gate", "cell_prism", "tower_cluster", "seven_vessels", "winged_cradle"],
    "heart": ["mouth_restraint", "pulse_mandala", "bound_gate", "cell_crown", "tower_cluster", "seven_reservoirs", "winged_seal"],
}
TRADITIONS = ["Christian", "Buddhist", "Shinto", "Islamic", "Hindu", "Jewish", "ancient Egyptian"]
# Authored commitments and resource routes are fixtures, not a runtime framework.
COUNTS = {"nursery": 28, "ossuary": 27, "inversion": 30, "heart": 32}
ARENAS = {"nursery": [24, 4, 36, 14], "heart": [26, 3, 41, 16]}
# Preserved pre-role archetypes. These only certify the ORIGINAL pistol support,
# not completion against late HP, summoner births, guardian armor or bosses.
BASELINE = {
    "nursery": "ccccwwwaccccwwwacwwcwwccwwwa",
    "ossuary": "wcwcwacwwcwcwacwwcwcwcwcawc",
    "inversion": "wcwcwacwwwcwcwacwwwcwwccwcacwc",
    "heart": "wcwcwacwwcwcwcwacwwcwcwwccwcacwc",
}
LATE_ROLES = {"brute", "guardian", "summoner"}
BOSSES = {"nursery": ("nursery_warden", "nursery_warden"), "heart": ("heart_choir_avatar", "choir_avatar")}


def check_roles(level, data):
    for kind in ["brute", "guardian", "summoner"]:
        assert any(p["kind"] == kind for p in data["enemies"]), f"LATE ENCOUNTERS RED: {level} requires an authored {kind}"
        ids = {p["id"] for p in data["enemies"] if p["kind"] == kind}
        assert any(group["id"] != level + "_finale" and ids.intersection(group["enemy_ids"]) for group in data["encounters"]), "introduce each regular late role in branch/return commitments"


def source_profiles():
    # These existing constants are JSON literals; no GDScript parser or framework.
    player = (ROOT / "game/scripts/player.gd").read_text()
    enemy = (ROOT / "game/scripts/enemy.gd").read_text()
    weapons = json.loads(player.split("const WEAPONS = ", 1)[1].split("const SPREAD", 1)[0].strip())
    roles = json.loads(enemy.split("const LATE = ", 1)[1].split("\n\nvar game: Node", 1)[0].strip())
    assert [p["max_ammo"] for p in weapons] == [0, 180, 32, 240, 24, 120]
    assert [roles[k]["hp"] for k in ["brute", "guardian", "summoner", "nursery_warden", "choir_avatar"]] == [210, 260, 150, 1200, 1600]
    return weapons, roles


def mixed_budgets(level, data, weapons, profiles, reachable, incoming_weapons=None):
    """Fixed single-target spending trace, not an optimizer or native fight."""
    inherited = {0, 1}
    inherited_sources = []
    if incoming_weapons is None:
        for prior in list(FILES)[:list(FILES).index(level)]:
            for p in json.loads((ROOT / "game/data" / (FILES[prior] + ".json")).read_text())["pickups"]:
                if p["kind"] == "weapon":
                    inherited.add(p["weapon"])
                    inherited_sources.append(p["id"])
    else:
        inherited = set(incoming_weapons)
    # No ammo carry, melee, infighting, splash or aligned-target subsidy. Six
    # close scatter pellets only. Guardian credit uses its CLOSED frontal armor.
    credit = [0, weapons[1]["damage"], weapons[2]["damage"] * min(6, weapons[2]["pellets"]),
              weapons[3]["damage"], weapons[4]["damage"], weapons[5]["damage"]]
    armored = [0, max(1, int(credit[1] * .35)), min(6, weapons[2]["pellets"]) * max(1, int(weapons[2]["damage"] * .35)),
               max(1, int(credit[3] * .35)), max(1, int(credit[4] * .35)), max(1, int(credit[5] * .35))]
    priority = {"brute": [2, 4, 5, 3, 1], "guardian": [4, 5, 2, 3, 1], "summoner": [3, 1, 5, 2, 4],
                "nursery_warden": [4, 5, 3, 2, 1], "choir_avatar": [4, 5, 3, 2, 1]}
    actors = {p["id"]: p for p in data["enemies"]}
    groups = {p["id"]: p for p in data["encounters"]}
    supplies = [p for p in data["pickups"] if p["kind"] in {"weapon", "ammo"}]
    output = []
    for difficulty, scale in enumerate([.85, 1, 1.3]):
        for order in [("first", "second"), ("second", "first")]:
            ammo, owned, consumed, activated, seals = [0] * 6, set(inherited), set(), set(), set()
            trace, deficits = [], []
            stages = [(branch, stage, supply) for branch in order for stage, supply in [("commit", "approach"), ("return", "return")]] + [("finale", "", "")]
            available_prefixes = [level + "_entry_"]
            for branch, stage, supply in stages:
                gid = level + "_" + branch + ("_" + stage if stage else "")
                if stage == "return":
                    seal = "blood" if branch == "first" else "ivory"
                    key = next(p for p in data["interactions"] if p["kind"] == "key" and p["key"] == seal)
                    before_seal = reachable(seals, [p["region"] for p in groups.values() if p["id"] not in activated and set(p["requires"]) <= seals])
                    assert tuple(map(math.floor, key["cell"])) in before_seal, "branch seal must be reachable after its commitment without another eligible dormant threshold"
                    seals.add(seal)
                available_prefixes.append(level + "_" + branch + ("_" + supply + "_" if supply else "_"))
                avoid = [p["region"] for p in groups.values() if p["id"] not in activated and set(p["requires"]) <= seals]
                safe = reachable(seals, avoid)
                if branch == "finale":
                    checkpoint = next(p for p in data["interactions"] if p["kind"] == "checkpoint")
                    assert tuple(map(math.floor, checkpoint["cell"])) in safe, "recovery checkpoint must precede any remaining eligible final threshold"
                collected = []
                # Weapon acquisition precedes its loose ammo; each real pod is
                # consumed once (clipping loses the excess, full pods remain).
                for p in sorted(supplies, key=lambda p: p["kind"] != "weapon"):
                    if p["id"] in consumed or tuple(map(math.floor, p["cell"])) not in safe:
                        continue
                    staged = any(tag in p["id"] for tag in ["_entry_", "_approach_", "_return_", "_finale_"])
                    if staged and not any(p["id"].startswith(tag) for tag in available_prefixes): continue
                    w = p["weapon"]
                    acquired = p["kind"] == "weapon" and w not in owned
                    if w not in owned and not acquired: continue
                    if not acquired and ammo[w] == weapons[w]["max_ammo"]: continue
                    before = ammo[w]
                    owned.add(w)
                    ammo[w] = min(weapons[w]["max_ammo"], before + p["amount"])
                    consumed.add(p["id"])
                    collected.append({"id": p["id"], "cell": p["cell"], "weapon": w, "amount": p["amount"], "before": before,
                                      "after": ammo[w], "clipped": before + p["amount"] - ammo[w], "acquired": acquired})
                demands = []
                for id in groups[gid]["enemy_ids"]:
                    kind = actors[id]["kind"]
                    hp = int(profiles.get(kind, {"hp": 50 if kind == "crawler" else 90})["hp"] * scale)
                    demands.append((id, kind, hp))
                    if kind == "summoner":
                        demands.extend((id + f"/birth-ceiling-{n}", "crawler", int(50 * scale)) for n in range(1, 7))
                allocations = []
                for id, kind, hp in demands:
                    remaining, used = hp, [0] * 6
                    damage = armored if kind == "guardian" else credit
                    for w in priority.get(kind, [1, 3, 2, 5, 4]):
                        if w not in owned: continue
                        hits = min(math.ceil(remaining / damage[w]), ammo[w] // 2)
                        # ceil(landed shots * 1.20 / .60) == two units per hit.
                        ammo[w] -= 2 * hits
                        used[w] += 2 * hits
                        remaining = max(0, remaining - hits * damage[w])
                        if remaining == 0: break
                    allocations.append({"id": id, "kind": kind, "hp": hp, "ammo": used, "unfunded_hp": remaining})
                    if remaining: deficits.append({"group": gid, "id": id, "kind": kind, "unfunded_hp": remaining})
                trace.append({"group": gid, "seals": sorted(seals), "pickups_before_commit": collected,
                              "owned": sorted(owned), "allocations": allocations, "remaining_ammo": ammo.copy()})
                activated.add(gid)
            output.append({"difficulty": difficulty, "scale": scale, "first_branch": order[0], "credit": credit,
                           "closed_guardian_credit": armored, "inherited_weapon_pickup_ids": inherited_sources,
                           "incoming_weapons": sorted(inherited), "incoming_ammo": [0] * 6,
                           "trace": trace, "deficits": deficits, "remaining_ammo": ammo})
    return output


def check_layout(level, data, incoming_weapons=None):
    assert data.get("id") == level and len(data.get("loops", [])) == 2, f"{level} requires its authored two-loop layout (intended RED)"
    assert data["cell_size"] == 4
    assert all(type(p.get("yaw")) in (int, float) and math.isfinite(p["yaw"]) for p in data["enemies"]), f"{level} requires finite authored actor yaw (intended RED)"
    tiles = {(x, z) for a, b, c, d in data["rects"] for x in range(a, c + 1) for z in range(b, d + 1)}

    def inside(p, r):
        return r[0] <= p[0] <= r[2] and r[1] <= p[1] <= r[3]

    def height(p):
        for r in data["elevations"]:
            if inside(p, r["rect"]):
                return r["height"] if "axis" not in r else max(0, min(1, (p[r["axis"]] - r["start"]) / (r["end"] - r["start"]))) * r["height"]
        return 0

    def floor(p):
        x, z = map(math.floor, p)
        u, v = p[0] - x, p[1] - z
        a, b, c, d = [height(q) for q in [(x, z), (x + 1, z), (x + 1, z + 1), (x, z + 1)]]
        return a + (b - a) * u + (c - b) * v if v <= u else a + (c - d) * u + (d - a) * v

    solids = [(p["cell"], p["base"], p.get("yaw", 0)) for p in data["heroes"] if "base" in p]
    solids += [(p["cell"], p["solid"], p.get("yaw", 0)) for p in data["scenery"] if "solid" in p]

    def clear(p, keys=("blood", "ivory"), radius=.65):
        margin = radius / 4
        if any((math.floor(p[0] + x), math.floor(p[1] + z)) not in tiles for x, z in [(0, 0), (-margin, -margin), (-margin, margin), (margin, -margin), (margin, margin)]):
            return False
        blocks = solids + [(p["cell"], p["size"], p["yaw"]) for p in data["doors"] if not set(p["requires"]) <= set(keys)]
        for c, dimensions, yaw in blocks:
            angle = math.radians(yaw)
            dx, dz = (p[0] - c[0]) * 4, (p[1] - c[1]) * 4
            x, z = dx * math.cos(angle) - dz * math.sin(angle), dx * math.sin(angle) + dz * math.cos(angle)
            if abs(x) < dimensions[0] / 2 + radius and abs(z) < dimensions[2] / 2 + radius:
                return False
        return True

    def segment(a, b, keys=("blood", "ivory"), avoid=()):
        steps = max(1, math.ceil(math.dist(a, b) * 8))
        previous = a
        for n in range(steps + 1):
            p = [a[i] + (b[i] - a[i]) * n / steps for i in range(2)]
            if any(inside(p, r) for r in avoid) or not clear(p, keys) or (n and abs(floor(p) - floor(previous)) > math.dist(p, previous) * 4 * .25 + 1e-8):
                return False
            previous = p
        return True

    def reachable(keys, avoid=()):
        start = tuple(map(math.floor, data["spawn"]))
        seen, queue = {start}, deque([start])
        while queue:
            x, z = queue.popleft()
            for q in [(x - 1, z), (x + 1, z), (x, z - 1), (x, z + 1)]:
                if q in tiles and q not in seen and segment([x + .5, z + .5], [q[0] + .5, q[1] + .5], keys, avoid):
                    seen.add(q)
                    queue.append(q)
        return seen

    expected = [level + "_" + i for i in ART[level]]
    assert len(data["heroes"]) == 2 and {p["id"] for p in data["heroes"]} == set(expected[:2]), f"{level} requires two unique hero records (intended bridge RED)"
    pieces = [(p["id"], p) for p in data["heroes"]] + [(p["art"], p) for p in data["scenery"] if p["art"] in expected]
    assert len(pieces) == 7 and {i for i, _ in pieces} == set(expected), "seven exact original machine placements"
    assert {p["tradition_aesthetic"] for _, p in pieces} == set(TRADITIONS)
    for art, p in pieces:
        assert p["tradition_aesthetic"] == TRADITIONS[expected.index(art)]
        assert p.get("yaw", 0) % 90 == 0
        scale = p.get("scale", [1, 1, 1])
        assert all(s == 1 for s in scale) if art in expected[:2] else all(.4 <= s <= .75 for s in scale)
        assert "scale" not in p if art in expected[:2] else True  # level.gd does not scale hero records.
        if art != "ossuary_rib_bridge":
            base = p.get("base", p.get("solid"))
            assert base and 0 < base[1] <= .55
        else:
            assert "solid" not in p and "base" not in p, "open bridge must not receive a whole central collider"
        sx, sz = (6 * scale[2], 8 * scale[0]) if p.get("yaw", 0) % 180 else (8 * scale[0], 6 * scale[2])
        for dx in [-sx / 8, sx / 8]:
            for dz in [-sz / 8, sz / 8]:
                q = [p["cell"][0] + dx, p["cell"][1] + dz]
                assert tuple(map(math.floor, q)) in tiles, "planned art envelope stays above native floor"
                roof = next((r["height"] for r in data["ceilings"] if inside(q, r["rect"])), 6)
                assert roof >= 9 * scale[1] + p.get("height", 0) + .75
    assert {p["hero"] for p in data["loops"]} == set(expected[:2])
    junction = data["loops"][0]["route"][0]
    for loop in data["loops"]:
        route = loop["route"]
        assert all(type(n) is int for p in route for n in p), "native loop anchors are integer cells"
        assert route[0] == route[-1] == junction and len({tuple(p) for p in route}) >= 6
        assert all(segment([a[0] + .5, a[1] + .5], [b[0] + .5, b[1] + .5]) for a, b in zip(route, route[1:])), "authored loops need clear capsule-width shallow paths"
        point = next(p["cell"] for art, p in pieces if art == loop["hero"])
        centred = [[x + .5, z + .5] for x, z in route]
        crossings = sum(point[0] < a[0] + (point[1] - a[1]) * (b[0] - a[0]) / (b[1] - a[1])
                        for a, b in zip(centred, centred[1:]) if (a[1] > point[1]) != (b[1] > point[1]))
        assert crossings % 2 == 1 or (loop["hero"] == "ossuary_rib_bridge" and point in centred), "each loop must organize around its own hero or cross the open bridge"
    assert height(pieces[0][1]["cell"]) != height(pieces[1][1]["cell"]) or level == "ossuary"
    ids = [p["id"] for k in ["heroes", "interactions", "doors", "enemies", "pickups", "encounters"] for p in data[k]]
    assert len(ids) == len(set(ids)) and all(i.startswith(level + "_") for i in ids)
    keys = {p["key"]: p for p in data["interactions"] if p["kind"] == "key"}
    others = {p["kind"]: p for p in data["interactions"] if p["kind"] != "key"}
    assert set(keys) == {"blood", "ivory"} and len(data["interactions"]) == 5
    assert set(others["exit"]["requires"]) == set(others["checkpoint"]["requires"]) == set(keys)
    assert "requires" not in others["story"] and len(others["story"]["text"]) < 240
    free = reachable(())
    assert all(tuple(map(math.floor, p["cell"])) in free for p in list(keys.values()) + [others["story"], others["checkpoint"]])
    end = tuple(map(math.floor, others["exit"]["cell"]))
    assert all(end not in reachable(k) for k in [(), ("blood",), ("ivory",)]), "two-seal gate must resist either single-seal bypass"
    assert end in reachable(keys)
    actors = {p["id"]: p for p in data["enemies"]}
    groups = {p["id"]: p for p in data["encounters"]}
    members = [i for p in groups.values() for i in p["enemy_ids"]]
    regular = {f"{level}_enemy_{i:02}": k for i, k in enumerate(BASELINE[level])}
    assert len(regular) == COUNTS[level]
    boss = BOSSES.get(level)
    assert set(actors) == set(regular) | ({boss[0]} if boss else set()), "preserve every original regular ID; only two explicitly authored bosses add actors"
    assert all(actors[i]["kind"] in {"crawler", "worker", "caster"} | LATE_ROLES for i in regular)
    assert {"crawler", "worker", "caster"} <= {actors[i]["kind"] for i in regular}, "retain original supported roles alongside the approved late introductions"
    assert len(actors) == COUNTS[level] + bool(boss)
    if boss:
        assert actors[boss[0]]["kind"] == boss[1] and others["exit"]["requires_defeated"] == [boss[0]]
        assert boss[0] in groups[level + "_finale"]["enemy_ids"] and set(groups[level + "_finale"]["requires"]) == set(keys)
    assert all("encounter" not in p and clear(p["cell"], radius=.44) for p in actors.values())
    assert len(groups) == 5 and len(members) == len(set(members)) and set(members) == set(actors), "authored groups are the sole membership source; entry actors remain dormant"
    weapons, profiles = source_profiles()
    staged = []
    for p in actors.values():
        profile = profiles.get(p["kind"], {"radius": .42 if p["kind"] == "crawler" else .34, "height": 1.1 if p["kind"] == "crawler" else 2.7})
        radius = profile["radius"]
        bottom = floor(p["cell"]) + .03 + (1 if p["kind"] in {"caster", "choir_avatar"} else 0)
        top = bottom + profile["height"]
        assert clear(p["cell"], keys=(), radius=max(.44, radius)), "enlarged actor footprint must clear actual solids, closed doors and floor edges"
        for dx, dz in [(0, 0), (-radius / 4, 0), (radius / 4, 0), (0, -radius / 4), (0, radius / 4)]:
            q = [p["cell"][0] + dx, p["cell"][1] + dz]
            roof = next((r["height"] for r in data["ceilings"] if inside(list(map(math.floor, q)), r["rect"])), 6)
            assert top + .03 < floor(q) + roof, "actual role capsule/hover must clear authored roof across its footprint"
        assert math.dist(p["cell"], data["spawn"]) * 4 > radius + .32, "actors cannot occupy the safe entry capsule"
        for other, other_radius, lo, hi in staged:
            assert math.dist(p["cell"], other) * 4 >= radius + other_radius or top <= lo or bottom >= hi, "enlarged authored actor capsules cannot overlap each other"
        staged.append((p["cell"], radius, bottom, top))
    lights = {p["id"]: p for p in data["lights"] if "id" in p}
    assert len(lights) == sum("id" in p for p in data["lights"]) and sum(p.get("shadow", False) for p in data["lights"]) <= 4
    for light in data["lights"]:
        assert tuple(map(math.floor, light["cell"])) in tiles, "lights need authored floor"
        roof = next((r["height"] for r in data["ceilings"] if inside(light["cell"], r["rect"])), 6)
        assert 0 < light["height"] < roof and light["energy"] > 0 and light["range"] > 0
    for group in groups.values():
        assert not inside(data["spawn"], group["region"]), "entry may not activate a combat group"
        assert group["cue"]["text"] and group["cue"]["sound"] == "seal_release"
        assert group["cue"]["light_ids"] and set(group["cue"]["light_ids"]) <= set(lights)
        assert set(group["requires"]) <= set(keys)
    for hero in data["heroes"]:
        assert hero["seal"] in keys and set(hero["light_ids"]) <= set(lights)
        if hero["id"] in {"nursery_gestation_engine", "heart_mouth_restraint"}:
            core = lights[hero["light_ids"][1]]
            assert math.dist(core["cell"], hero["cell"]) * data["cell_size"] < 8 and core["height"] <= 5.5, "examination light must reach modeled organism/mouth, not the distant vault"
            assert core.get("target") == hero["cell"], "repositioned examination spot must aim at its original hero"
    assert {tuple(p["requires"]) for p in groups.values()} >= {(), ("blood",), ("ivory",), ("blood", "ivory")}
    assert all(groups[f"{level}_{branch}_commit"]["requires"] == [] and groups[f"{level}_{branch}_return"]["requires"] == [seal] for branch, seal in [("first", "blood"), ("second", "ivory")])
    pickups = {p["id"]: p for p in data["pickups"]}
    assert all(clear(p["cell"], radius=.44) and tuple(map(math.floor, p["cell"])) in free for p in pickups.values())
    assert all(p.get("weapon", 0) in range(6) for p in pickups.values())
    assert all(type(p.get("amount")) is int and 0 <= p["amount"] <= weapons[p["weapon"]]["max_ammo"] for p in pickups.values() if p["kind"] in {"ammo", "weapon"}), "actual finite integral weapon pools are individually bounded by native capacity"
    for branch in ["first", "second"]:
        for stage, supply in [("commit", "approach"), ("return", "return")]:
            resource = pickups[f"{level}_{branch}_{supply}_rivets"]
            assert not inside(resource["cell"], groups[f"{level}_{branch}_{stage}"]["region"]), "resupply must precede commitment"
    finale = groups[level + "_finale"]
    assert not inside(others["checkpoint"]["cell"], finale["region"])
    assert not inside(pickups[level + "_finale_rivets"]["cell"], finale["region"])
    reserve = {}
    for scale in [.85, 1, 1.3]:
        for order in [("first", "second"), ("second", "first")]:
            ammo = pickups[level + "_entry_rivets"]["amount"]
            for branch in order:
                for stage, supply in [("commit", "approach"), ("return", "return")]:
                    ammo = min(180, ammo + pickups[f"{level}_{branch}_{supply}_rivets"]["amount"])
                    cost = 2 * sum(math.ceil(int((50 if regular[i] == "c" else 90) * scale) / 22) for i in groups[f"{level}_{branch}_{stage}"]["enemy_ids"] if i in regular)
                    assert ammo >= cost, "pistol fallback needs 60% hit / 20% recovery margin at each commitment"
                    ammo -= cost
            ammo = min(180, ammo + pickups[level + "_finale_rivets"]["amount"])
            ammo -= 2 * sum(math.ceil(int((50 if regular[i] == "c" else 90) * scale) / 22) for i in finale["enemy_ids"] if i in regular)
            assert ammo >= 20, "supported actor completion needs a final recovery reserve; no boss/late-weapon subsidy"
            reserve[f"{scale}/{order[0]}"] = ammo
    if level in ARENAS:
        r = ARENAS[level]
        assert (r[2] - r[0] + 1) * 4 >= 40 and (r[3] - r[1] + 1) * 4 >= 32
        perimeter = [[r[0] + 1.5, r[1] + 1.5], [r[2] - .5, r[1] + 1.5], [r[2] - .5, r[3] - .5], [r[0] + 1.5, r[3] - .5]]
        assert all(segment(a, b) for a, b in zip(perimeter, perimeter[1:] + perimeter[:1])), "reserved boss arena needs a connected clear dodge perimeter"
        assert any(inside(c, r) and d[1] >= 1.6 for c, d, _ in solids), "arena needs real existing solid cover"
        assert clear([(r[0] + r[2] + 1) / 2, (r[1] + r[3] + 1) / 2])
    if level == "ossuary":
        bridge = next(p for art, p in pieces if art == "ossuary_rib_bridge")
        assert bridge["seal"] == "blood" and bridge["light_ids"] == ["ossuary_bridge_feed", "ossuary_bridge_core"]
        x, z = bridge["cell"]
        assert segment([x, z - 1.5], [x, z + 1.5]), "rib bridge central transport passage must remain open"
        assert sum(abs(c[0] - x) < 1 and abs(c[1] - z) < 1 for c, _, _ in solids) == 4, "four independent lateral bridge support bases"
    budgets = mixed_budgets(level, data, weapons, profiles, reachable, incoming_weapons)
    return {"level": level, "tiles": len(tiles), "actors": len(actors), "loops": 2, "planned_machines": 7,
            "baseline_pistol_support_only": reserve, "mixed_arsenal_routes": budgets}


def check(level, data):
    check_roles(level, data)
    result = check_layout(level, data)
    assert all(not route["deficits"] for route in result["mixed_arsenal_routes"]), "actual mixed arsenal needs finite before-commit pools for late HP/add ceilings/bosses in both orders and all modes"
    return result


def check_minimum_heart_arsenal(data):
    """Actual pools with missed optional weapons; a spending model, not native fights."""
    routes = check_layout("heart", data, incoming_weapons=(0, 1, 2))["mixed_arsenal_routes"]
    assert {(r["difficulty"], r["first_branch"]) for r in routes} == {
        (mode, branch) for mode in range(3) for branch in ("first", "second")}
    assert all(r["incoming_weapons"] == [0, 1, 2] and r["incoming_ammo"] == [0] * 6 for r in routes)
    assert all(not r["deficits"] for r in routes), "Heart minimum arsenal needs finite before-commit pools without granting missed earlier weapons"
    for route in routes:
        finale = next(stage for stage in route["trace"] if stage["group"] == "heart_finale")
        pod = next(p for p in finale["pickups_before_commit"] if p["id"] == "heart_finale_launcher")
        assert pod["acquired"] and pod["weapon"] == 4 and pod["amount"] == 8
    return routes


if __name__ == "__main__":
    levels = [sys.argv[sys.argv.index("--level") + 1]] if "--level" in sys.argv else list(FILES)
    for level in levels:
        path = ROOT / "game/data" / (FILES[level] + ".json")
        data = json.loads(path.read_text()) if path.is_file() else {}
        # Geometry/budget reporting is explicitly separate from integrated GREEN.
        layout_only = "--boundary-checks" in sys.argv or "--budget-report" in sys.argv
        print(json.dumps(check_layout(level, data) if layout_only else check(level, data), indent=2))
        if level == "heart" and not layout_only:
            check_minimum_heart_arsenal(data)
            reverted = copy.deepcopy(data)
            next(p for p in reverted["pickups"] if p["id"] == "heart_finale_launcher")["kind"] = "ammo"
            try:
                check_minimum_heart_arsenal(reverted)
            except AssertionError as error:
                assert str(error) == "Heart minimum arsenal needs finite before-commit pools without granting missed earlier weapons"
            else:
                raise AssertionError("Heart launcher catch-up regression was not rejected")
            print("PASS modeled Heart minimum arsenal: six routes, actual catch-up pod, ammo-only reversion rejected; NOT native boss completion")
        if "--boundary-checks" in sys.argv:
            print("CHECKER BOUNDARIES: actual geometry/baseline control; not authored late-role/native GREEN")
            for label in ["broken_loop", "duplicate_membership", "one_seal_gate", "entry_activation", "shadow_overflow", "ammo_starvation", "light_above_roof", "missing_yaw", "nan_yaw", "infinite_yaw", "missing_unique_hero", "regular_id_loss", "nonfinite_pool", "negative_pool", "over_cap_pool", "actor_overlap", "enlarged_solid_overlap", "capsule_above_roof"]:
                bad = copy.deepcopy(data)
                if label == "broken_loop": bad["loops"][0]["route"][2] = [-20, -20]
                if label == "duplicate_membership": bad["encounters"][1]["enemy_ids"][0] = bad["encounters"][0]["enemy_ids"][0]
                if label == "one_seal_gate": bad["doors"][0]["requires"] = ["blood"]
                if label == "entry_activation": bad["encounters"][0]["region"] = [data["spawn"][0] - 1, data["spawn"][1] - 1, data["spawn"][0] + 1, data["spawn"][1] + 1]
                if label == "shadow_overflow": bad["lights"][0]["shadow"] = True
                if label == "ammo_starvation": bad["pickups"][0]["amount"] = 0
                if label == "light_above_roof": bad["lights"][0]["height"] = 100
                if label == "missing_yaw": bad["enemies"][0].pop("yaw")
                if label == "nan_yaw": bad["enemies"][0]["yaw"] = float("nan")
                if label == "infinite_yaw": bad["enemies"][0]["yaw"] = float("inf")
                if label == "missing_unique_hero": bad["heroes"].pop(0)
                if label == "regular_id_loss": bad["enemies"][0]["id"] += "_changed"
                if label == "nonfinite_pool": bad["pickups"][0]["amount"] = float("inf")
                if label == "negative_pool": bad["pickups"][0]["amount"] = -1
                if label == "over_cap_pool": bad["pickups"][0]["amount"] = 181
                if label == "actor_overlap": bad["enemies"][1]["cell"] = bad["enemies"][0]["cell"][:]
                if label == "enlarged_solid_overlap":
                    bad["enemies"][0]["kind"] = "guardian"
                    hero = next(p for p in bad["heroes"] if "base" in p)
                    angle = math.radians(hero["yaw"])
                    offset = (hero["base"][0] / 2 + .55) / 4
                    bad["enemies"][0]["cell"] = [hero["cell"][0] + offset * math.cos(angle), hero["cell"][1] - offset * math.sin(angle)]
                if label == "capsule_above_roof":
                    bad["enemies"][0]["kind"] = "summoner"
                    bad["ceilings"].insert(0, {"rect": [math.floor(bad["enemies"][0]["cell"][0]), math.floor(bad["enemies"][0]["cell"][1])] * 2, "height": 3})
                try:
                    check_layout(level, bad)
                except AssertionError as error:
                    print(f"REJECTED {level}/{label}: {error}")
                else:
                    raise AssertionError(f"accepted regression: {level}/{label}")
            # In-memory checker controls, NOT authored assignments/native actors.
            control = copy.deepcopy(data)
            original = {f"{level}_enemy_{i:02}": {"c": "crawler", "w": "worker", "a": "caster"}[k] for i, k in enumerate(BASELINE[level])}
            for actor in control["enemies"]:
                if actor["id"] in original: actor["kind"] = original[actor["id"]]
            actors = {p["id"]: p for p in control["enemies"]}
            for group, kind in zip(control["encounters"][:3], ["brute", "guardian", "summoner"]):
                actor = next(actors[i] for i in group["enemy_ids"] if actors[i]["kind"] == "worker")
                actor["kind"] = kind
            check_roles(level, control)
            normal = check(level, control)
            print(f"SIMULATED {level}/role-budget positive checker control accepted; no production/native claim")
            for kind in ["brute", "guardian", "summoner"]:
                bad = copy.deepcopy(control)
                for actor in bad["enemies"]:
                    if actor["kind"] == kind: actor["kind"] = "worker"
                try:
                    check_roles(level, bad)
                except AssertionError as error:
                    assert str(error) == f"LATE ENCOUNTERS RED: {level} requires an authored {kind}"
                    print(f"REJECTED {level}/missing_{kind}: {error}")
                else:
                    raise AssertionError(f"accepted missing role: {level}/{kind}")
            bad = copy.deepcopy(control)
            brute_id = next(p["id"] for p in bad["enemies"] if p["kind"] == "brute")
            for group in bad["encounters"]:
                if brute_id in group["enemy_ids"]: group["enemy_ids"].remove(brute_id)
                if group["id"] == level + "_finale": group["enemy_ids"].append(brute_id)
            try:
                check_roles(level, bad)
            except AssertionError as error:
                assert str(error) == "introduce each regular late role in branch/return commitments"
                print(f"REJECTED {level}/finale_only_introduction: {error}")
            else:
                raise AssertionError(f"accepted finale-only role introduction: {level}")
            starved = copy.deepcopy(control)
            for p in starved["pickups"]:
                if p.get("weapon", 0) >= 2: p["amount"] = 0
            result = check_layout(level, starved)
            assert result["baseline_pistol_support_only"] == normal["baseline_pistol_support_only"]
            assert any(r["deficits"] for r in result["mixed_arsenal_routes"]), "original pistol support cannot certify new-role completion"
            print(f"REJECTED {level}/mixed_resource_starvation despite unchanged original pistol support")
