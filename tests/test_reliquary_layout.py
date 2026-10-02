"""Source checks for the authored archive, not native traversal or visual acceptance."""
import copy
import json
import math
import sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAP = ROOT / "game/data/04_reliquary.json"
TRADITIONS = {
    "reliquary_face_halo": "Christian",
    "reliquary_memory_wheel": "Buddhist",
    "reliquary_bound_gate": "Shinto",
    "reliquary_cell_vault": "Islamic",
    "reliquary_tower_cluster": "Hindu",
    "reliquary_seven_vessels": "Jewish",
    "reliquary_winged_seal": "ancient Egyptian",
}


def check(data):
    assert len(data.get("loops", [])) == 2, "Reliquary requires two authored original landmark loops (intended RED)"
    assert data["id"] == "reliquary" and data["cell_size"] == 4
    tiles = {(x, z) for a, b, c, d in data["rects"] for x in range(a, c + 1) for z in range(b, d + 1)}
    size = data["cell_size"]

    def inside(p, r):
        return r[0] <= p[0] <= r[2] and r[1] <= p[1] <= r[3]

    def height(p):
        # Match level_data.gd's first-region, zero-to-height ramp convention.
        for r in data["elevations"]:
            if inside(p, r["rect"]):
                if "axis" not in r:
                    return r["height"]
                return max(0, min(1, (p[r["axis"]] - r["start"]) / (r["end"] - r["start"]))) * r["height"]
        return 0

    def floor(p):
        # Native floor uses triangles 0,1,2 and 0,2,3, not analytic ramp samples.
        x, z = math.floor(p[0]), math.floor(p[1])
        u, v = p[0] - x, p[1] - z
        a, b, c, d = [height(q) for q in [(x, z), (x + 1, z), (x + 1, z + 1), (x, z + 1)]]
        return a + (b - a) * u + (c - b) * v if v <= u else a + (c - d) * u + (d - a) * v

    solids = [(p["cell"], p["base"], p.get("yaw", 0)) for p in data["heroes"]]
    solids += [(p["cell"], p["solid"], p.get("yaw", 0)) for p in data["scenery"] if "solid" in p]

    def clear(p, keys=("blood", "ivory"), radius=0.65):
        margin = radius / size
        if any((math.floor(p[0] + dx), math.floor(p[1] + dz)) not in tiles
               for dx, dz in [(0, 0), (-margin, -margin), (-margin, margin), (margin, -margin), (margin, margin)]):
            return False
        blockers = solids + [(d["cell"], d["size"], d["yaw"]) for d in data["doors"] if not set(d["requires"]) <= set(keys)]
        for center, dimensions, yaw in blockers:
            angle = math.radians(yaw)
            dx, dz = (p[0] - center[0]) * size, (p[1] - center[1]) * size
            x, z = dx * math.cos(angle) - dz * math.sin(angle), dx * math.sin(angle) + dz * math.cos(angle)
            if abs(x) < dimensions[0] / 2 + radius and abs(z) < dimensions[2] / 2 + radius:
                return False
        return True

    def segment(a, b, keys=("blood", "ivory")):
        distance = math.dist(a, b)
        steps = max(1, math.ceil(distance * 8))
        previous = a
        for n in range(steps + 1):
            p = [a[i] + (b[i] - a[i]) * n / steps for i in range(2)]
            if not clear(p, keys):
                return False
            if n and abs(floor(p) - floor(previous)) > math.dist(p, previous) * size * 0.25 + 1e-8:
                return False
            previous = p
        return True

    def reachable(keys):
        start = tuple(map(math.floor, data["spawn"]))
        seen, queue = {start}, deque([start])
        while queue:
            x, z = queue.popleft()
            for nxt in [(x - 1, z), (x + 1, z), (x, z - 1), (x, z + 1)]:
                if nxt not in seen and nxt in tiles and segment([x + .5, z + .5], [nxt[0] + .5, nxt[1] + .5], keys):
                    seen.add(nxt)
                    queue.append(nxt)
        return seen

    def surrounds(point, route):
        crossings = 0
        for a, b in zip(route, route[1:]):
            if (a[1] > point[1]) != (b[1] > point[1]):
                crossings += point[0] < a[0] + (point[1] - a[1]) * (b[0] - a[0]) / (b[1] - a[1])
        return crossings % 2 == 1

    heroes = {p["id"]: p for p in data["heroes"]}
    assert set(heroes) == {"reliquary_face_halo", "reliquary_memory_wheel"}
    assert {r["hero"] for r in data["loops"]} == set(heroes)
    assert all(type(n) is int for r in data["loops"] for p in r["route"] for n in p), "loop routes use native traversal helper's integer cell anchors"
    anchor = data["loops"][0]["route"][0]
    assert anchor == [19, 11], "both seal-return galleries must meet the northern catalogue junction before the exit"
    junction = [n + .5 for n in anchor]
    assert all(r["route"][0] == anchor == r["route"][-1] for r in data["loops"]), "loops must close at the same readable return junction"
    for loop in data["loops"]:
        route = [[n + .5 for n in p] for p in loop["route"]]
        assert len({tuple(p) for p in route}) >= 6 and surrounds(heroes[loop["hero"]]["cell"], route)
        assert all(segment(a, b) for a, b in zip(route, route[1:])), "loop must clear the planned capsule, solid bases and shallow floor triangles"
    assert segment(data["spawn"], [19.5, 35.5]) and segment([19.5, 35.5], junction)
    # Explicit alternate sides of each hero; neither flank crosses its solid base.
    assert segment([11.5, 20.5], [11.5, 12.5]) and segment([28.5, 19.5], [28.5, 11.5])
    assert height(heroes["reliquary_face_halo"]["cell"]) == -2
    assert height(heroes["reliquary_memory_wheel"]["cell"]) == 2

    pieces = [(p["id"], p) for p in data["heroes"]] + [(p["art"], p) for p in data["scenery"] if p["art"] in TRADITIONS]
    assert len(pieces) == 7 and {i for i, _ in pieces} == set(TRADITIONS), "exactly one placement per religious machine"
    assert {p["tradition_aesthetic"] for _, p in pieces} == set(TRADITIONS.values())
    for art, p in pieces:
        assert p["tradition_aesthetic"] == TRADITIONS[art]
        scale = p.get("scale", [1, 1, 1])
        assert "scale" not in p if art in heroes else all(.4 <= s <= .75 for s in scale)
        assert p.get("yaw", 0) % 180 == 0
        base = p.get("base", p.get("solid"))
        assert base and 0 < base[1] <= .55, "religious machines use low explicit bases, not imagined anatomy collision"
        for dx in [-4 * scale[0] / size, 4 * scale[0] / size]:
            for dz in [-3 * scale[2] / size, 3 * scale[2] / size]:
                q = [p["cell"][0] + dx, p["cell"][1] + dz]
                assert tuple(map(math.floor, q)) in tiles, "planned 8x6m art envelope must remain over authored floor"
                roof = next((r["height"] for r in data["ceilings"] if inside(q, r["rect"])), 6)
                assert roof >= 9 * scale[1] + p.get("height", 0) + .75, "planned 9m art envelope needs roof margin"

    ids = [p["id"] for key in ["heroes", "doors", "interactions", "pickups", "enemies", "encounters"] for p in data[key]]
    assert len(ids) == len(set(ids)) and all(i.startswith("reliquary_") for i in ids)
    interactions = {p["kind"]: p for p in data["interactions"] if p["kind"] != "key"}
    keys = {p["key"]: p for p in data["interactions"] if p["kind"] == "key"}
    assert set(keys) == {"blood", "ivory"} and len(data["interactions"]) == 5
    assert set(interactions["exit"]["requires"]) == set(interactions["checkpoint"]["requires"]) == set(keys)
    checkpoint = interactions["checkpoint"]["cell"]
    catalogue = next(p for p in data["encounters"] if p["id"] == "reliquary_catalogue")
    assert interactions["exit"]["cell"][1] < catalogue["region"][3] + .8 < checkpoint[1] < junction[1], "northern return must store recovery before the final catalogue commitment"
    assert "requires" not in interactions["story"] and "voice" in interactions["story"]["text"].lower()
    ungated = reachable(())
    assert all(tuple(map(math.floor, p["cell"])) in ungated for p in list(keys.values()) + [interactions["story"], interactions["checkpoint"]])
    exit_cell = tuple(map(math.floor, interactions["exit"]["cell"]))
    assert all(exit_cell not in reachable(k) for k in [(), ("blood",), ("ivory",)]), "neither seal alone may bypass the native gate envelope"
    assert len(data["doors"]) == 1 and set(data["doors"][0]["requires"]) == set(keys)
    assert exit_cell in reachable(keys)

    actors = {p["id"]: p for p in data["enemies"]}
    assert all(isinstance(p.get("yaw"), (int, float)) and math.isfinite(p["yaw"]) for p in actors.values()), "all native enemy specs require authored finite yaw (intended RED)"
    assert len(actors) == 31 and {p["kind"] for p in actors.values()} == {"crawler", "worker", "caster"}
    assert all("encounter" not in p and clear(p["cell"], radius=.44) for p in actors.values())
    groups = {p["id"]: p for p in data["encounters"]}
    members = [i for p in groups.values() for i in p["enemy_ids"]]
    assert len(groups) == 6 and len(members) == len(set(members)) and set(members) == set(actors), "one authored encounter membership source; quiet entry has no active actors"
    lights = {p["id"]: p for p in data["lights"] if "id" in p}
    assert len(lights) == sum("id" in p for p in data["lights"])
    assert sum(p.get("shadow", False) for p in data["lights"]) <= 4
    for p in list(groups.values()) + list(heroes.values()):
        cue = p.get("cue", p)
        assert cue["light_ids"] and set(cue["light_ids"]) <= set(lights)
        if "cue" in p:
            assert p["cue"]["text"] and p["cue"]["sound"] == "seal_release"
            assert set(p["requires"]) <= set(keys)
            assert not inside(data["spawn"], p["region"]), "safe entry must not activate any group"
            assert any(inside([x + .5, z + .5], p["region"]) for x, z in tiles)
    assert {p["seal"] for p in heroes.values()} == set(keys)
    assert {tuple(p["requires"]) for p in groups.values()} >= {(), ("blood",), ("ivory",), ("blood", "ivory")}

    pickups = {p["id"]: p for p in data["pickups"]}
    assert all(clear(p["cell"], radius=.44) and tuple(map(math.floor, p["cell"])) in ungated for p in data["pickups"])
    assert {p["weapon"] for p in data["pickups"] if "weapon" in p} <= {1, 2}
    assert any(p["kind"] == "weapon" and p["weapon"] == 2 for p in data["pickups"])
    for branch in ["halo", "wheel"]:
        for side in ["approach", "return"]:
            supply = pickups[f"reliquary_{branch}_{side}_rivets"]
            commit = groups[f"reliquary_{branch}_commit"]
            assert not inside(supply["cell"], commit["region"]), "supplies precede either landmark commitment"
        supply = pickups[f"reliquary_{branch}_return_rivets"]["cell"]
        region = groups[f"reliquary_{branch}_return"]["region"]
        assert supply[0] < region[0] if branch == "halo" else supply[0] > region[2], "return supplies must precede the eastbound halo / westbound wheel response"
    # Current fixed modes: 50/90 HP * .85/1/1.3, pistol 22, cap 180.
    # Budget a pistol-only route at 60% hits plus 20% recovery (2x perfect).
    # Scatter shells/impact remain alternatives, not a hidden completion subsidy.
    remaining = {}
    for scale in [.85, 1, 1.3]:
        for order in [("halo", "wheel"), ("wheel", "halo")]:
            ammo = pickups["reliquary_entry_rivets"]["amount"]
            for branch in order:
                for stage, supply in [("commit", "approach"), ("return", "return")]:
                    ammo = min(180, ammo + pickups[f"reliquary_{branch}_{supply}_rivets"]["amount"])
                    group = groups[f"reliquary_{branch}_{stage}"]
                    cost = 2 * sum(math.ceil(int((50 if actors[i]["kind"] == "crawler" else 90) * scale) / 22) for i in group["enemy_ids"])
                    assert ammo >= cost, f"{branch}/{stage} needs a fixed-mode recovery margin"
                    ammo -= cost
            for stage in ["catalogue", "exit"]:
                ammo = min(180, ammo + pickups[f"reliquary_{stage}_rivets"]["amount"])
                cost = 2 * sum(math.ceil(int((50 if actors[i]["kind"] == "crawler" else 90) * scale) / 22) for i in groups[f"reliquary_{stage}"]["enemy_ids"])
                assert ammo >= cost, f"{stage} needs a fixed-mode recovery margin"
                ammo -= cost
            assert ammo >= 20, "completion must retain a recovery reserve on either seal order"
            remaining[f"{scale}/{order[0]}-first"] = ammo
    return {"tiles": len(tiles), "loops": 2, "machines": 7, "enemies": len(actors), "fixed_mode_route_rivets_remaining": remaining}


if __name__ == "__main__":
    data = json.loads(MAP.read_text()) if MAP.is_file() else {}
    print(json.dumps(check(data), indent=2))
    if "--boundary-checks" in sys.argv:
        for label in ["broken_loop", "duplicate_member", "one_seal_gate", "missing_cue_light", "insufficient_ammo", "low_roof"]:
            bad = copy.deepcopy(data)
            if label == "broken_loop": bad["loops"][0]["route"][2] = [0, 39]
            if label == "duplicate_member": bad["encounters"][1]["enemy_ids"][0] = bad["encounters"][0]["enemy_ids"][0]
            if label == "one_seal_gate": bad["doors"][0]["requires"] = ["blood"]
            if label == "missing_cue_light": bad["encounters"][0]["cue"]["light_ids"] = ["missing"]
            if label == "insufficient_ammo": bad["pickups"][0]["amount"] = 0
            if label == "low_roof": bad["ceilings"] = [{"rect": [0, 0, 40, 40], "height": 6}]
            try:
                check(bad)
            except AssertionError as error:
                print(f"REJECTED {label}: {error}")
            else:
                raise AssertionError(f"accepted regression: {label}")
        print("Boundary checks: both seal orders, all fixed modes, blocked single-seal exits, six rejected regressions")
