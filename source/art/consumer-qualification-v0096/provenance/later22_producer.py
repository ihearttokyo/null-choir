"""Source-only v0.096 per-job contract builder and context validator.

This module does not launch Godot, stage sources, create captures, or qualify a
receipt. A successful result means only that a future private context packet is
internally bound to its declared source/case/fixture/controller and typed trace.
"""
from __future__ import annotations

import hashlib
import json
import math
import re
import stat
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[2]
SCHEMA_PATH = HERE / "CASE-SCHEMA.json"
SOURCE_PINS_PATH = HERE / "CURRENT-SOURCE-PINS.json"
ORIGINAL_CASES_PATH = HERE / "CAPTURE-CASES22-REFERENCE.json"
SCOUT_PATH = PROJECT / "work/earned-arsenal-prep/authored-rivet70-source-scout/PROPOSED-ENCOUNTER.json"
SCOUT_REPORT_PATH = PROJECT / "work/earned-arsenal-prep/authored-rivet70-source-scout/REPORT.md"
SCOUT_NEAR_MID_PATH = PROJECT / "work/earned-arsenal-prep/authored-rivet70-source-scout/near-mid-same-spine.json"
SCOUT_REVIEW_PATH = PROJECT / "work/preview07-local-control/reviews/cohort-ledger-review/authored-rivet70-source-review.md"
FIXTURE_PATH = HERE / "qualify_v0096_gameplay_context.gd"
PRODUCER_PATH = HERE / "later22_producer.py"
HEX64 = re.compile(r"^[0-9a-f]{64}$")

class ContractError(ValueError):
    pass

def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def file_sha(path: Path) -> str:
    return sha(path.read_bytes())

def source_build_version(project: Path = PROJECT) -> str:
    source = (project / "game/scripts/build_info.gd").read_text(encoding="utf-8")
    match = re.search(r'^const DISPLAY_NAME = "(Null Choir v0\.096)"$', source, re.MULTILINE)
    _need(match is not None, "Current source build identity must be v0.096")
    return match.group(1)

def _need(ok: bool, message: str) -> None:
    if not ok:
        raise ContractError(message)

def _vec_close(actual: Any, expected: Any, tolerance: float = .001) -> bool:
    return (type(actual) is list and type(expected) is list and len(actual) == len(expected)
            and all(abs(float(a)-float(b)) <= tolerance for a,b in zip(actual,expected)))

def _regular(root: Path, relative: str) -> Path:
    rel = Path(relative)
    _need(not rel.is_absolute() and ".." not in rel.parts and relative.startswith("game/"),
          f"Unsafe current dependency path: {relative}")
    path = root / rel
    for part in (path, *path.parents):
        _need(not part.is_symlink(), f"Symlink current dependency refused: {relative}")
    info = path.lstat()
    _need(stat.S_ISREG(info.st_mode), f"Resident regular dependency required: {relative}")
    return path

def load_source_manifest(path: Path = SOURCE_PINS_PATH) -> tuple[dict[str, Any], bytes]:
    raw = path.read_bytes()
    doc = json.loads(raw)
    _need(doc.get("schema") == "null-choir-v096-adapter-current-source-pin-inventory-v1"
          and doc.get("status") == "SOURCE_INVENTORY_ONLY_NOT_QUALIFICATION",
          "Source inventory must remain explicitly non-qualifying")
    _need(doc.get("native_imports") == "UNPINNED_SOURCE_CONFIG_ONLY",
          "Native import/cache proof remains UNPINNED")
    sources, assets = doc.get("source_dependencies"), doc.get("art_resource_dependencies")
    _need(type(sources) is dict and len(sources) == 47
          and type(assets) is dict and len(assets) == 262,
          "Exact current 47-source/262-art dependency inventory required")
    for group in (sources, assets):
        for relative, row in group.items():
            _need(type(row) is dict and set(row) == {"path", "bytes", "sha256"}
                  and relative == row["path"] and type(row["bytes"]) is int
                  and type(row["bytes"]) is not bool and HEX64.fullmatch(str(row["sha256"])),
                  "Typed exact dependency row required")
    return doc, raw

def verify_source_inventory(project: Path = PROJECT,
                            source_manifest_path: Path = SOURCE_PINS_PATH) -> tuple[dict[str, Any], str]:
    manifest, raw = load_source_manifest(source_manifest_path)
    for row in list(manifest["source_dependencies"].values()) + list(manifest["art_resource_dependencies"].values()):
        path = _regular(project, row["path"])
        data = path.read_bytes()
        _need(len(data) == row["bytes"] and sha(data) == row["sha256"],
              f"Stale/foreign current source dependency: {row['path']}")
    return manifest, sha(raw)

def _source_json(project: Path, manifest: dict[str, Any], relative: str) -> dict[str, Any]:
    row = manifest["source_dependencies"].get(relative)
    _need(type(row) is dict and row.get("path") == relative,
          f"Required causal source dependency is not pinned: {relative}")
    data = _regular(project, relative).read_bytes()
    _need(len(data) == row["bytes"] and sha(data) == row["sha256"],
          f"Causal source dependency changed: {relative}")
    result = json.loads(data)
    _need(type(result) is dict, f"Expected current authored JSON source: {relative}")
    return result

def _authored_station_contract(case: dict[str, Any], project: Path, manifest: dict[str, Any]) -> dict[str, dict[str, Any]]:
    placements = _source_json(project, manifest, "game/data/healing_machine_placements.json")
    supplies = _source_json(project, manifest, "game/data/earned_supplies.json")
    registry = _source_json(project, manifest, "game/data/healing_machinery_registry.json")
    layout = _source_json(project, manifest, f"game/data/{case['scene_chapter']+1:02d}_{case['scene_id']}.json")
    chapter = supplies.get("chapters", {}).get(case["scene_id"], {})
    stations = chapter.get("stations")
    _need(type(stations) is list and len(stations) == 4, "Four source-authored current healing stations required")
    result: dict[str, dict[str, Any]] = {}
    for station in stations:
        ident = station.get("id")
        placement = placements.get(ident)
        _need(type(placement) is dict and placement.get("chapter") == case["scene_id"]
              and placement.get("id") == ident and type(placement.get("cell")) is list
              and len(placement["cell"]) == 2, f"Source placement identity mismatch: {ident}")
        family = placement["family"]
        family_spec = registry.get("families", {}).get(family)
        _need(type(family_spec) is dict and type(family_spec.get("nodes")) is dict
              and type(family_spec.get("nodes", {}).get("UseTarget")) is list
              and len(family_spec["nodes"]["UseTarget"]) >= 4,
              f"Source family/control registry missing for {ident}")
        cell_size = float(layout.get("cell_size", 0))
        cell = [float(v) for v in placement["cell"]]
        _need(cell_size > 0, f"Source layout cell size missing: {case['scene_id']}")
        # Match LevelData.world_position's ordinary authored-floor interpolation.
        # Current Ossuary placements are outside its source-defined cut patch;
        # a future station inside that patch fails closed until triangle-derived y is added.
        if case["scene_id"] == "ossuary":
            world_x, world_z = cell[0]*cell_size, cell[1]*cell_size
            _need(not (20.0 <= world_x <= 32.0 and 66.0 <= world_z <= 78.0),
                  "Ossuary placement in patched triangle field needs exact surface-derived source pose")
        def height_at(x: float, z: float) -> float:
            for region in layout.get("elevations", []):
                x0,z0,x1,z1 = map(float, region["rect"])
                if x < x0 or z < z0 or x > x1 or z > z1:
                    continue
                if "axis" in region:
                    axis = int(region["axis"])
                    _need(axis in (0, 1), "Exact production numeric elevation axis required")
                    start,end = float(region["start"]),float(region["end"])
                    if start == end:
                        return float(region["height"])
                    return max(0.0,min(1.0,((x,z)[axis]-start)/(end-start))) * float(region["height"])
                return float(region["height"])
            return 0.0
        x,z = cell
        ix,iz = int(x//1),int(z//1)
        ux,uz = x-ix,z-iz
        a=height_at(ix,iz); b=height_at(ix+1,iz) if uz<=ux else 0.0
        c=height_at(ix+1,iz+1); d=0.0 if uz<=ux else height_at(ix,iz+1)
        y = a+(b-a)*ux+(c-b)*uz if uz<=ux else a+(c-d)*ux+(d-a)*uz
        yaw = float(placement["yaw_degrees"])
        control_local = [float(v) for v in family_spec["nodes"]["UseTarget"][3]]
        angle = yaw * 3.141592653589793 / 180.0
        anchor_local = [control_local[0]*math.cos(angle)+control_local[2]*math.sin(angle),
                        control_local[1],-control_local[0]*math.sin(angle)+control_local[2]*math.cos(angle)]
        dial_pin = family_spec["nodes"].get("DialFace")
        _need(type(dial_pin) is list and len(dial_pin) >= 3,
              f"Current imported family lacks exact DialFace transform pin: {ident}")
        # Production _specs applies String.validate_node_name to flat imported
        # parts. Current exact source names only need its dot replacement; no
        # wildcard/part omission or geometry waiver is allowed.
        raw_names = list(family_spec["nodes"])
        _need(all(re.fullmatch(r'[A-Za-z0-9_.-]+', name) for name in raw_names),
              "New Godot-invalid node characters require an explicit source mapping")
        imported_names = [name.replace(".", "_") for name in raw_names]
        _need(len(set(imported_names)) == len(raw_names), "Imported part-name mapping collision")
        result[ident] = {"id":ident,"chapter":case["scene_id"],"family":family,
            "capacity":int(station["capacity"]),"root_local":[x*cell_size,y,z*cell_size],
            "yaw_degrees":yaw,"front_anchor_offset":anchor_local,
            "dial_face_local_position":dial_pin[3] if len(dial_pin)>3 else [0,0,0],
            "dial_face_local_scale":dial_pin[4] if len(dial_pin)>4 else [1,1,1],
            "fixed_triangle_faces":int(family_spec["fixedTriangles"]),
            "mesh_names":sorted(imported_names)}
    return result

def _source_weapon_specs(project: Path, manifest: dict[str, Any]) -> list[dict[str, Any]]:
    row = manifest["source_dependencies"].get("game/scripts/player.gd")
    _need(type(row) is dict, "Pinned production Player source required")
    source = _regular(project, row["path"]).read_text(encoding="utf-8")
    _need(sha(source.encode()) == row["sha256"], "Production Player source drift")
    pattern = re.compile(r'\{"name":"([^"]+)","asset":"([^"]+)","damage":(\d+),"interval":([0-9.]+),"range":([0-9.]+),"pellets":(\d+),"max_ammo":(\d+),"low_ammo":(\d+),"useful_range":([0-9.]+)\}')
    entries = pattern.findall(source)
    _need(len(entries) == 6, "Six exact production weapon definitions required")
    return [{"name":n,"asset":a,"damage":int(d),"interval":float(i),"range":float(r),
             "pellets":int(p),"max_ammo":int(m),"low_ammo":int(l),"useful_range":float(u)}
            for n,a,d,i,r,p,m,l,u in entries]

def load_case_schema(path: Path = SCHEMA_PATH) -> tuple[dict[str, Any], bytes]:
    raw = path.read_bytes(); doc = json.loads(raw)
    _need(doc.get("schema") == "null-choir-v096-capture-case-schema-v2"
          and doc.get("status") == "PROPOSAL_SOURCE_ONLY_NOT_CAPTURE_OR_QUALIFICATION"
          and doc.get("case_count") == 22 and type(doc.get("cases")) is list
          and len(doc["cases"]) == 22,
          "Exact unchanged 22-case proposal schema required")
    map_path = HERE / doc.get("station_view_map_path", "")
    _need(doc.get("original_contract_sha256") == file_sha(ORIGINAL_CASES_PATH)
          and doc.get("source_pin_manifest_sha256") == file_sha(SOURCE_PINS_PATH)
          and doc.get("station_view_map_sha256") == file_sha(map_path),
          "Case schema must bind the untouched 22 cases, source inventory, and 32-station view map")
    view_map = json.loads(map_path.read_bytes())
    mapped = view_map.get("placements")
    _need(view_map.get("placement_count") == 32 and type(mapped) is list and len(mapped) == 32
          and len({row.get("station_id") for row in mapped}) == 32
          and len({row.get("family") for row in mapped}) == 8,
          "Exact eight-family/32-unique-station view mapping required")
    expected = {(case["id"], view["station_id"], view["family"], view["frame_label"])
                for case in doc["cases"] if case.get("mode") == "routes"
                for view in case.get("station_views", [])}
    observed = {(row.get("route_case"), row.get("station_id"), row.get("family"), row.get("frame_label"))
                for row in mapped}
    _need(len(expected) == 32 and observed == expected
          and all(row.get("claim") == "required current visible-control frame; no new route case replaces any of the original 22"
                  for row in mapped),
          "Every current placement must join one exact unchanged chapter-route frame")
    overrides = [row.get("producer_scene_override") for row in doc["cases"] if row.get("producer_scene_override")]
    if overrides:
        _need(len(overrides) in (1, 6), "Only original Rivet or Rootsharedsixweapon arrangements allowed")
        for override in overrides:
            _need(file_sha(SCOUT_PATH) == override.get("source_scout_proposal_sha256")
                  and file_sha(SCOUT_REPORT_PATH) == override.get("source_scout_report_sha256")
                  and file_sha(SCOUT_NEAR_MID_PATH) == override.get("source_scout_near_mid_sha256")
                  and file_sha(SCOUT_REVIEW_PATH) == override.get("source_admission_review_sha256"),
                  "Shared arrangement must retain exact original reviewed source-scout packet")
    return doc, raw

def effective_case(case: dict[str, Any]) -> dict[str, Any]:
    """Apply an explicitly versioned producer-only scene arrangement; source reference remains unchanged."""
    result = dict(case)
    override = case.get("producer_scene_override")
    if override is not None:
        weapon = case.get("weapon")
        _need(type(weapon) is int and 0 <= weapon <= 5 and case.get("id") == f"weapon-{weapon}-roles",
              "Only exact original weapon cases may use RootsharedWorker arrangement")
        original = next(row for row in json.loads(ORIGINAL_CASES_PATH.read_bytes())["jobs"] if row["id"] == case["id"])
        expected_ranges = original["preferred_ranges_m"]
        expected_players = [[86.0, .04, 118.0-distance] for distance in expected_ranges]
        if weapon == 1: expected_players[-1][0] = 85.99999999999999
        caps = [2.7, 140.0, 32.0, 140.0, 96.0, 24.0]
        _need(override.get("status") == ("SOURCE_CANDIDATE_PASS_NATIVE_ADMISSION_REQUIRED" if weapon == 1 else "ROOT_AUTHORIZED_SHARED_WORKER_NATIVE_ADMISSION_REQUIRED")
              and override.get("scene_chapter") == 3 and override.get("scene_id") == "reliquary"
              and override.get("actor_id") == "reliquary_enemy_05"
              and override.get("actor_original_world") == [18.0,-2.97,50.0]
              and override.get("actor_original_yaw_degrees") == -155.556
              and override.get("arrangement_id") == "reliquary-spine-B"
              and override.get("target_worker_world") == [86.0,0.03,118.0]
              and override.get("player_candidates_world") == expected_players
              and override.get("witness") == {"source_atlas_pixel":[703,63],"source_row":0,"source_frame":5,"alpha":255,"force_sprite_frame":False}
              and override.get("frame_labels") == case.get("frames")
              and case.get("preferred_ranges_m") == override.get("requested_ranges_m") == expected_ranges
              and override.get("weapon_range_cap_m") == caps[weapon]
              and override.get("source_scout_proposal_sha256") == "bc9db94dc5519af61bba231a652028f8998c6d484e9a26cd317b0618a0c8dd5d"
              and override.get("source_scout_near_mid_sha256") == "cf891524d4bd316888d78e2e0c737e8ce104d2b87b407d56e4579b48dc2feb58"
              and override.get("source_scout_report_sha256") == "bd8a15f3a446b6b5f144ce140763ab8d77cbc12c2ebd7bdaa6fcd6f43b3d3f20"
              and override.get("source_admission_review_sha256") == "1a76218f2fe085a8018c26e0f43374ecf64790d52e7fb9106d6d8ad7b047e723",
              "Unsupported/unversioned shared original-range Worker arrangement")
        result["scene_chapter"] = override["scene_chapter"]
        result["scene_id"] = override["scene_id"]
        result["preferred_ranges_m"] = override["requested_ranges_m"]
        result["role_arrangement"] = override
    return result

def case_for(case_id: str, schema: dict[str, Any]) -> dict[str, Any]:
    matches = [row for row in schema["cases"] if row.get("id") == case_id]
    _need(len(matches) == 1, f"Unknown/duplicate source capture case: {case_id}")
    return matches[0]

def build_job_contract(case_id: str, *, controller_path: Path,
                       project: Path = PROJECT,
                       schema_path: Path = SCHEMA_PATH,
                       source_manifest_path: Path = SOURCE_PINS_PATH,
                       fixture_path: Path = FIXTURE_PATH,
                       producer_path: Path = PRODUCER_PATH) -> dict[str, Any]:
    """Build a case-bound handoff record; caller must bind the actual runner file."""
    schema, schema_raw = load_case_schema(schema_path)
    manifest, source_manifest_sha = verify_source_inventory(project, source_manifest_path)
    row = effective_case(case_for(case_id, schema))
    original_raw = ORIGINAL_CASES_PATH.read_bytes()
    _need(sha(original_raw) == schema["original_contract_sha256"],
          "Original 22 case contract changed")
    return {
        "schema": "null-choir-v096-capture-case-v2",
        "build_version": source_build_version(project),
        "case_id": row["id"], "mode": row["mode"], "chapter": row["chapter"],
        "weapon": row["weapon"], "scene_chapter": row["scene_chapter"],
        "scene_id": row["scene_id"], "frame_labels": row["frames"],
        "preferred_ranges_m": row.get("preferred_ranges_m", []),
        "role_arrangement": row.get("role_arrangement", {}),
        "fixture_sha256": file_sha(fixture_path),
        "producer_sha256": file_sha(producer_path),
        "capture_controller_sha256": file_sha(controller_path),
        "case_schema_sha256": sha(schema_raw),
        "source_manifest_sha256": source_manifest_sha,
        "original22_contract_sha256": sha(original_raw),
        "native_imports": manifest["native_imports"],
    }

def _canonical_state(row: dict[str, Any], owner: str) -> dict[str, Any]:
    state_json = row.get("state_json")
    _need(type(state_json) is str, f"Missing serialized state snapshot in {owner}")
    raw = state_json.encode("utf-8")
    _need(HEX64.fullmatch(str(row.get("state_sha256", "")))
          and sha(raw) == row["state_sha256"], f"State snapshot hash mismatch in {owner}")
    parsed = json.loads(state_json)
    _need(type(parsed) is dict and parsed == row.get("state"),
          f"Serialized state/snapshot mismatch in {owner}")
    return parsed

def _trace_provenance(row: dict[str, Any], case_id: str, expected: dict[str, Any], where: str) -> None:
    for key in ("case_id", "scene_id", "source_manifest_sha256", "fixture_sha256",
                "producer_sha256", "capture_controller_sha256", "case_schema_sha256"):
        wanted = expected["scene_id"] if key == "scene_id" else expected["case_id"] if key == "case_id" else expected[key]
        _need(row.get(key) == wanted, f"Wrong {key} join in {where}")
    _need(type(row.get("trace_seq")) is int and type(row.get("trace_seq")) is not bool
          and row["trace_seq"] > 0, f"Typed trace sequence required in {where}")
    state = _canonical_state(row, where)
    _need(state.get("scene_id") == expected["scene_id"]
          and state.get("level_index") == expected["scene_chapter"],
          f"State scene/chapter mismatch in {where}")

def _as_vec(value: Any, n: int = 3) -> list[float]:
    _need(type(value) is list and len(value) == n, "Typed source-bound vector required")
    try:
        result = [float(x) for x in value]
    except (TypeError, ValueError) as exc:
        raise ContractError("Non-numeric source-bound vector") from exc
    _need(all(math.isfinite(x) for x in result), "Finite source-bound vector required")
    return result

def _actor_state(state: dict[str, Any], ident: str) -> dict[str, Any]:
    actors = state.get("actors")
    _need(type(actors) is list, "Serialized actor roster required")
    matches = [row for row in actors if type(row) is dict and row.get("id") == ident]
    _need(len(matches) == 1, f"Exactly one current serialized actor required: {ident}")
    return matches[0]

def _machine_state(state: dict[str, Any], ident: str) -> dict[str, Any]:
    machines = state.get("machines")
    _need(type(machines) is list, "Serialized current machine roster required")
    matches = [row for row in machines if type(row) is dict and row.get("id") == ident]
    _need(len(matches) == 1, f"Exactly one current serialized machine required: {ident}")
    return matches[0]

def _near_vec(actual: Any, expected: Any, tol: float = .002) -> bool:
    try:
        a, e = _as_vec(actual), _as_vec(expected)
    except ContractError:
        return False
    return all(abs(x-y) <= tol for x, y in zip(a, e))

def _near_xz(actual: Any, expected: Any, tol: float = .02) -> bool:
    try:
        a, e = _as_vec(actual), _as_vec(expected)
    except ContractError:
        return False
    return abs(a[0]-e[0]) <= tol and abs(a[2]-e[2]) <= tol

def _require_actor_death_joins(grant, scenes, labels, by_kind):
    lethal = by_kind.get("arranged_lethal_damage_production_callbacks_not_earned_combat", [])
    expected_deaths = {str(grant["carrier"])}
    expected_deaths.update(str(x["seal_bearer"]) for x in scenes.get("interactions", []) if x.get("seal_bearer"))
    expected_deaths.update(str(x) for interaction in scenes.get("interactions", []) if interaction.get("kind") == "exit"
                           for x in interaction.get("requires_defeated", []))
    _need(len(lethal) == len(expected_deaths) and {row.get("actor") for row in lethal} == expected_deaths,
          "Exact authored carrier, both seal-bearers, and exit-warden death set required")
    source_actor_ids = {str(x.get("id")) for x in scenes.get("enemies", []) if type(x) is dict and x.get("id")}
    for death in lethal:
        ident = death.get("actor")
        _need(type(ident) is str and ident in source_actor_ids, "Typed current authored production actor identity required")
        is_carrier = ident == grant.get("carrier")
        interaction = next((x for x in scenes.get("interactions", []) if x.get("seal_bearer") == ident), None)
        exit_target = any(ident in x.get("requires_defeated", []) for x in scenes.get("interactions", []) if x.get("kind") == "exit")
        before_label = "carrier-live" if is_carrier else (str(interaction["key"])+"-live" if interaction else "exit-warden-live")
        after_label = "carrier-corpse-drop" if is_carrier else (str(interaction["key"])+"-corpse-drop" if interaction else "exit-warden-defeated")
        _need(before_label and after_label, f"Production actor death lacks before/after frame join: {ident}")
        a = _actor_state(labels[before_label]["state"], ident); b = _actor_state(labels[after_label]["state"], ident)
        event_actor = _actor_state(death.get("state", {}), ident)
        _need(int(a.get("hp", 0)) == int(death.get("before_hp", -1)) > 0
              and int(b.get("hp", -1)) == int(death.get("after_hp", -2)) == 0
              and int(event_actor.get("hp", -1)) == 0
              and _near_vec(event_actor.get("world_position"), b.get("world_position"))
              and ident in labels[after_label]["state"].get("removed", [])
              and death.get("state", {}).get("removed") == labels[after_label]["state"].get("removed"),
              f"Production lethal scalar is not caused by serialized actor state: {ident}")
        if interaction:
            collected=labels[str(interaction["key"])+"-collected"]["state"]
            _need(ident in collected.get("removed", []) and interaction["id"] in collected.get("removed", [])
                  and str(interaction["key"]) in collected.get("keys", []),
                  f"Seal bearer death, key and source removal do not form one transaction: {ident}")
        if exit_target:
            _need(ident in labels["exit-warden-defeated"]["state"].get("removed", []),
                  "Exit warden defeat does not join the authored exit frame")

def _require_events(case: dict[str, Any], events: list[dict[str, Any]],
                    frames: list[dict[str, Any]], motion: list[dict[str, Any]],
                    project: Path, manifest: dict[str, Any]) -> None:
    by_kind: dict[str, list[dict[str, Any]]] = {}
    for event in events:
        by_kind.setdefault(str(event.get("kind", "")), []).append(event)
    labels = {row["label"]: row for row in frames}
    mode = case["mode"]
    scenes = _source_json(project, manifest, f"game/data/{case['scene_chapter']+1:02d}_{case['scene_id']}.json")
    scene_events = by_kind.get("production_scene_ready", [])
    expected_resets = 6 if mode == "weapon-roles" else 1
    _need(len(scene_events) == expected_resets,
          "Exact current production scene-ready reset count required for case lifecycle")
    for scene_event in scene_events:
        _need(scene_event.get("scene_id") == case["scene_id"]
              and scene_event.get("chapter_index") == case["scene_chapter"]
              and scene_event.get("selected_level_transition") == "new_campaign_then_complete_level"
              and scene_event.get("fresh_selected_finite_state_valid") is True
              and scene_event.get("checkpoint_envelope_valid") is True
              and scene_event.get("level_start_envelope_valid") is True,
              "Selected finite state must follow valid production progression/checkpoint/start envelopes")
    if mode == "weapon-roles":
        for index, scene_event in enumerate(scene_events):
            following = scene_events[index+1]["trace_seq"] if index+1 < len(scene_events) else float("inf")
            group = [frame for frame in frames if scene_event["trace_seq"] < frame["trace_seq"] < following]
            expected_group = case["frames"][index:index+1] if expected_resets == 6 else case["frames"][index*3:index*3+3]
            _need([frame["label"] for frame in group] == expected_group,
                  "Each fresh production scene must own exactly its original normal/reduced role bins")
    if mode == "routes":
        expected_machines = _authored_station_contract(case, project, manifest)
        required = {v["station_id"]: v for v in case["station_views"]}
        _need(set(required) == set(expected_machines), "Route case must cover exact four current source stations")
        observed: dict[str, dict[str, Any]] = {}
        for row in by_kind.get("actual_visible_machine_view", []):
            ident = row.get("station")
            if ident in required:
                _need(ident not in observed, f"Duplicate machine-view trace for {ident}")
                observed[ident] = row
        _need(set(observed) == set(required), "All four current chapter machine views required")
        controls = by_kind.get("actual_imported_machine_mesh_stock_collider_negative_contract", [])
        required_controls = {"baseline", "hidden_visible_control", "misplaced_dial_face", "foreign_dial_mesh",
            "misplaced_machine_root", "foreign_family_identity", "wrong_runtime_stock_book",
            "misplaced_stock_volume_mesh", "substituted_visible_collision"}
        _need(len(controls) == 1 and controls[0].get("exact_restoration") is True
              and type(controls[0].get("controls")) is dict
              and set(controls[0]["controls"]) == required_controls
              and type(controls[0].get("evidence")) is dict
              and set(controls[0]["evidence"]) == required_controls
              and all(controls[0]["controls"][key] is True for key in required_controls)
              and type(controls[0].get("same_root_instance")) is int and controls[0]["same_root_instance"] > 0
              and type(controls[0].get("same_control_instance")) is int and controls[0]["same_control_instance"] > 0
              and controls[0]["same_root_instance"] != controls[0]["same_control_instance"],
              "Complete nonempty current imported family/control/mesh/stock/collider negative contract required")
        evidence = controls[0]["evidence"]
        for name in required_controls:
            proof = evidence[name]
            _need(type(proof) is dict and type(proof.get("before")) is dict
                  and type(proof.get("during")) is dict and type(proof.get("restored")) is dict
                  and proof["before"] == proof["restored"],
                  f"Negative control {name} must include restored actual object-state snapshots")
            if name == "baseline":
                _need(proof["before"] == proof["during"] and proof.get("rejected") is False,
                      "Baseline control must prove current positive source object state")
                _need(proof["before"].get("family") == controls[0].get("family")
                      and proof["before"].get("remaining", -1) >= 0
                      and proof["before"].get("capacity", 0) > 0
                      and proof["before"].get("triangle_faces", 0) > 0,
                      "Baseline actual machine object snapshot must be nonempty/current")
            else:
                _need(proof["during"] != proof["before"] and proof.get("rejected") is True,
                      f"Negative control {name} must show actual changed object state refused by production")
        expected_mutations = {
            "hidden_visible_control": ("dial_visible", False),
            "misplaced_dial_face": ("dial_transform", None),
            "foreign_dial_mesh": ("dial_mesh_class", "SphereMesh"),
            "misplaced_machine_root": ("root_transform", None),
            "foreign_family_identity": ("family", "foreign-family"),
            "wrong_runtime_stock_book": ("remaining", None),
            "misplaced_stock_volume_mesh": ("stock_transform", None),
            "substituted_visible_collision": ("shape_class", "BoxShape3D"),
        }
        for name, (field, exact) in expected_mutations.items():
            before, during = evidence[name]["before"], evidence[name]["during"]
            _need((during.get(field) == exact) if exact is not None else (during.get(field) != before.get(field)),
                  f"Negative control {name} did not change its concrete target object")
        control_station = controls[0].get("station")
        _need(control_station in expected_machines and controls[0].get("family") == expected_machines[control_station]["family"],
              "Negative controls must target a current source-authored station/family")
        control_state_machine = _machine_state(controls[0].get("state", {}), control_station)
        baseline = evidence["baseline"]["before"]
        control_source = expected_machines[control_station]
        _need(control_state_machine.get("root_instance") == controls[0].get("same_root_instance")
              and control_state_machine.get("control_instance") == controls[0].get("same_control_instance")
              and _near_vec(controls[0].get("front_anchor_world"), control_state_machine.get("front_anchor_world"))
              and _near_vec(controls[0].get("dial_face_center_world"), control_state_machine.get("dial_face_center_world"))
              and _near_vec(control_state_machine.get("root_local"), control_source["root_local"])
              and _near_vec(control_state_machine.get("dial_face_local_position"), control_source["dial_face_local_position"])
              and _near_vec(control_state_machine.get("dial_face_local_scale"), control_source["dial_face_local_scale"])
              and _near_vec(control_state_machine.get("dial_face_local_rotation"), [0,0,0])
              and control_state_machine.get("fixed_triangle_faces") == control_source["fixed_triangle_faces"],
              "Negative-control baseline must join the exact live source station instance and pose")
        _need(control_state_machine.get("family") == baseline.get("family")
              and control_state_machine.get("remaining") == baseline.get("remaining")
              and control_state_machine.get("capacity") == baseline.get("capacity")
              and control_state_machine.get("fixed_triangle_faces") == baseline.get("triangle_faces"),
              "Negative-control baseline actual object snapshot must join serialized live machine state")
        for ident, view in required.items():
            row = observed[ident]; source = expected_machines[ident]
            frame = labels[view["frame_label"]]
            _need(frame.get("subject") == ident and row.get("family") == source["family"] == view["family"]
                  and row.get("chapter") == case["scene_id"]
                  and row.get("deep_station_validation") is True and row.get("finite_stock_book_validation") is True
                  and row.get("nearest_station") == ident
                  and row.get("station") == ident
                  and type(row.get("stock")) is int and 0 <= row["stock"] <= source["capacity"]
                  and row.get("capacity") == source["capacity"]
                  and row.get("fixed_triangle_faces") == source["fixed_triangle_faces"]
                  and set(row.get("mesh_names", [])) == set(source["mesh_names"]),
                  f"Current source family/control/capacity/geometry identity mismatch: {ident}")
            _need(_near_vec(row.get("root_local"), source["root_local"])
                  and _near_vec(row.get("root_world"), source["root_local"])
                  and abs((float(row.get("yaw_degrees", 999))-source["yaw_degrees"]+180.0)%360.0-180.0) < .01,
                  f"Machine root/yaw is inconsistent with current source placement: {ident}")
            _need(_near_vec(row.get("dial_face_local_position"), source["dial_face_local_position"])
                  and _near_vec(row.get("dial_face_local_scale"), source["dial_face_local_scale"])
                  and _near_vec(row.get("dial_face_local_rotation"), [0,0,0]),
                  f"Visible DialFace local pose differs from exact current family registry: {ident}")
            root_world = _as_vec(row.get("root_world")); anchor = _as_vec(row.get("front_anchor_world"))
            expected_offset = source["front_anchor_offset"]
            _need(_near_vec([anchor[i]-root_world[i] for i in range(3)], expected_offset),
                  f"Front anchor does not match the actual imported UseTarget pose: {ident}")
            dial = _as_vec(row.get("dial_face_center_world"))
            _need(math.dist(dial, anchor) < .5 and row.get("fixed_triangle_faces", 0) > 0,
                  f"Visible control or exact fixed geometry is absent: {ident}")
            machine = _machine_state(frame.get("state", {}), ident)
            for key in ("chapter", "family", "remaining", "capacity", "root_local", "root_world", "yaw_degrees",
                        "front_anchor_world", "dial_face_center_world", "mesh_names", "fixed_triangle_faces"):
                event_key = "stock" if key == "remaining" else key
                _need(machine.get(key) == row.get(event_key)
                      if key not in ("root_local", "root_world", "front_anchor_world", "dial_face_center_world")
                      else _near_vec(machine.get(key), row.get(event_key)),
                      f"Frame and causal event machine snapshot diverge: {ident}/{key}")
            _need(frame.get("state", {}).get("healing_remaining", {}).get(ident) == row["stock"],
                  f"Frame stock state does not match current finite machine book: {ident}")
        loop_ids = [str(loop.get("id", "")) for loop in scenes.get("loops", [])]
        _need(len(loop_ids) == 2 and all(loop_ids), "Two exact source-authored loop ids required")
        observed_loops = {row.get("loop") for row in motion}
        _need(observed_loops == set(loop_ids), "Motion trace must use the exact authored loop ids")
        for loop_id in loop_ids:
            rows = sorted((row for row in motion if row.get("loop") == loop_id), key=lambda row: row["trace_seq"])
            _need(len(rows) >= 24 and all(row.get("action") == "move_forward" and row.get("floor") is True
                    and type(row.get("state")) is dict
                    and _near_vec(row.get("foot"), row["state"].get("player_position"))
                    and _near_vec(row.get("velocity"), row["state"].get("player_velocity"))
                    for row in rows), f"Incomplete actual player motion state for authored loop {loop_id}")
            points = [_as_vec(row["foot"]) for row in rows]
            _need(math.dist(points[0], points[-1]) >= 1.0
                  and any(math.sqrt(sum(float(v)*float(v) for v in row["velocity"])) > .05 for row in rows),
                  f"Authored loop {loop_id} has no actual player displacement")
        _need(labels["exit-threat-tell"].get("subject") and labels["wall-local-light"].get("subject"),
              "Threat and original wall/floor frames required")
    elif mode == "transactions":
        supplies = _source_json(project, manifest, "game/data/earned_supplies.json")["chapters"][case["scene_id"]]
        before_ammo = labels["carrier-corpse-drop"]["state"]
        after_ammo = labels["carrier-collected"]["state"]
        ammo_events = by_kind.get("production_walkover_ammo", [])
        _need(len(ammo_events) == 1, "One authored walkover-ammo transaction required")
        ammo = ammo_events[0]; grant = next((g for g in supplies.get("grants", []) if g.get("id") == ammo.get("grant")), None)
        _need(type(grant) is dict and grant.get("kind") == "ammo" and grant.get("weapon") == 1,
              "Ammo transaction must bind an authored ordinary Rivet grant")
        _need(int(ammo.get("before", -1)) == before_ammo["ammo"][1]
              and int(ammo.get("after", -1)) == after_ammo["ammo"][1]
              and int(ammo["after"]) > int(ammo["before"])
              and after_ammo["ammo"][1] - before_ammo["ammo"][1] in [int(x) for x in grant.get("quantities", [])]
              and ammo.get("drop_state") == ammo.get("state", {}).get("earned_supply")
              and after_ammo.get("earned_supply") == ammo.get("drop_state")
              and ammo.get("state", {}).get("ammo", [])[1] == after_ammo["ammo"][1]
              and ammo.get("state", {}).get("earned_supply") == after_ammo.get("earned_supply"),
              "Serialized current supply/ammo states must causally match authored walkover grant")
        actual_drops = before_ammo.get("earned_supply", {}).get("loot_drops")
        _need(type(actual_drops) is list, "Actual uncollected carrier loot-drop state required")
        selected_drops = [drop for drop in actual_drops if type(drop) is dict and drop.get("grant_id") == grant["id"]]
        _need(len(selected_drops) == 1 and type(selected_drops[0].get("remaining")) is int
              and selected_drops[0]["remaining"] == int(ammo["after"])-int(ammo["before"])
              and not any(drop.get("grant_id") == grant["id"] for drop in after_ammo.get("earned_supply", {}).get("loot_drops", [])),
              "Selected real uncollected drop must uniquely transfer its actual remaining quantity")
        _as_vec(selected_drops[0].get("position"))
        practical_rows = by_kind.get("actual_applicable_drop_practical_negative_controls", [])
        _need(len(practical_rows) == 1, "Actual applicable uncollected-drop practical negative controls required")
        practical = practical_rows[0]; before_practical = practical.get("before", {}); after_practical = practical.get("after", {})
        _need(practical.get("grant") == grant["id"] and practical.get("applicable") is True
              and type(practical.get("applicable_count")) is int and practical["applicable_count"] >= 1
              and practical.get("no_drop_shortcut") is False
              and practical.get("method") == "_export_earned_drop_practical_negative_controls"
              and practical.get("checked_source_operations") == ["hidden", "substituted", "foreign", "nested", "restored"]
              and practical.get("returned_conjunction_pass") is True
              and practical.get("positive_before") is True and practical.get("positive_selected") is True and practical.get("positive_after") is True
              and practical.get("method_first_grant") == grant["id"]
              and practical.get("method_first_marker_instance") == before_practical.get("marker_instance")
              and practical.get("arranged_iteration_only_all_bindings_preserved") is True
              and type(practical.get("registry_bindings_before")) is dict and practical["registry_bindings_before"]
              and practical["registry_bindings_before"] == practical.get("registry_bindings_during") == practical.get("registry_bindings_after")
              and practical["registry_bindings_before"].get(grant["id"]) == before_practical.get("marker_instance")
              and practical.get("registry_order_before") == practical.get("registry_order_after")
              and type(practical.get("registry_order_before")) is list
              and set(practical["registry_order_before"]) == set(practical["registry_bindings_before"])
              and before_practical == after_practical
              and type(before_practical.get("marker_instance")) is int and before_practical["marker_instance"] > 0
              and type(before_practical.get("practical_instance")) is int and before_practical["practical_instance"] > 0
              and before_practical.get("parent_is_marker") is True and before_practical.get("visible") is True
              and before_practical.get("practical_source") == "earned_drop_case"
              and before_practical.get("source_role") == "earned_equipment_drop"
              and before_practical.get("shadow") is True
              and float(before_practical.get("energy", -1)) == 1.0 and float(before_practical.get("range", -1)) == 2.0
              and before_practical.get("drop_state") == before_ammo.get("earned_supply")
              and practical.get("state", {}).get("earned_supply") == before_ammo.get("earned_supply"),
              "Drop practical controls must select the real registered uncollected carrier drop and restore exact owned state/registry")
        heal = by_kind.get("synthetic_ownedWindow_Space_events_to_realPlayer_and_next_physics_tick_NOT_hardware", [])
        _need(len(heal) == 1, "One real Player.Space finite transfer required")
        heal_row = heal[0]; station_id = case["transaction_station_id"]
        pre, post = labels["reservoir-before"]["state"], labels["reservoir-after"]["state"]
        source_stations = _authored_station_contract(case, project, manifest)
        station_spec = source_stations.get(station_id)
        _need(type(station_spec) is dict, "Healing transaction station must be source registered")
        machine_before = _machine_state(pre, station_id); machine_after = _machine_state(post, station_id)
        _need(heal_row.get("station") == station_id
              and labels["reservoir-before"].get("subject") == station_id == labels["reservoir-after"].get("subject")
              and machine_before.get("family") == station_spec["family"] == machine_after.get("family")
              and machine_before.get("capacity") == station_spec["capacity"] == machine_after.get("capacity")
              and machine_before.get("remaining") == heal_row.get("stock_before")
              and machine_after.get("remaining") == heal_row.get("stock_after")
              and pre["health"] == heal_row.get("health_before") and post["health"] == heal_row.get("health_after")
              and pre["healing_remaining"].get(station_id) == heal_row.get("stock_before")
              and post["healing_remaining"].get(station_id) == heal_row.get("stock_after")
              and heal_row.get("health_after", 0) > heal_row.get("health_before", 0)
              and heal_row.get("stock_before", -1)-heal_row.get("stock_after", -1)
                  == heal_row.get("health_after", 0)-heal_row.get("health_before", 0)
              and heal_row.get("state", {}).get("health") == heal_row.get("health_after")
              and heal_row.get("state", {}).get("healing_remaining", {}).get(station_id) == heal_row.get("stock_after"),
              "Space healing scalar claims must join actual before/after player and station snapshots")
        # The frozen case lists semantic blood/ivory roles; actual authored
        # interaction IDs are chapter-specific and must be bound, never renamed.
        source_keys = [x for x in scenes.get("interactions", []) if x.get("kind") == "key"]
        roles = [str(key).removesuffix("_key") for key in case["expected_key_ids"]]
        _need(len(roles) == 2 and len(set(roles)) == 2 and len(source_keys) == 2
              and {x.get("key") for x in source_keys} == set(roles)
              and {str(x.get("key"))+"_key" for x in source_keys} == set(case["expected_key_ids"]),
              "Transaction key roles must bind exact unique source-authored blood/ivory interactions")
        source_key_by_role = {x["key"]:x for x in source_keys}
        actual_key_ids = [source_key_by_role[role].get("id") for role in roles]
        _need(all(type(ident) is str and ident for ident in actual_key_ids) and len(set(actual_key_ids)) == 2,
              "Exact unique authored key interaction IDs required")
        hints = by_kind.get("actual_auto_key_HUD_hint", [])
        _need(len(hints) == 2 and [row.get("key") for row in hints] == actual_key_ids
              and all(row.get("binding") == "" and str(row.get("prompt", "")).startswith("WALK OVER TO RECOVER") for row in hints),
              "Both distinct physical auto-key HUD transaction hints required")
        hint_by_key = {row.get("key"): row for row in hints}
        for key_id in case["expected_key_ids"]:
            prefix = key_id.removesuffix("_key")
            before = labels[f"{prefix}-corpse-drop"]["state"]
            after = labels[f"{prefix}-collected"]["state"]
            interaction = source_key_by_role[prefix]
            hint_state = hint_by_key[interaction["id"]].get("state", {})
            bearer = str(interaction.get("seal_bearer", ""))
            hint_actor = _actor_state(hint_state, bearer)
            _need(prefix not in before.get("keys", []) and prefix in after.get("keys", [])
                  and interaction["id"] not in before.get("removed", [])
                  and interaction["id"] in after.get("removed", [])
                  and hint_state.get("keys") == before.get("keys")
                  and hint_state.get("removed") == before.get("removed")
                  and int(hint_actor.get("hp", -1)) == 0 and bearer in hint_state.get("removed", []),
                  f"Key {key_id} HUD hint must join the current dead-bearer, uncollected before-pickup state")
        gate = by_kind.get("fresh_production_gate_release", [])
        _need(len(gate) == 1, "One fresh production exit gate transition required")
        gate_row = gate[0]; doors = scenes.get("doors", [])
        _need(type(doors) is list and bool(doors), "Source exit-door specification required")
        door_id = doors[-1].get("id")
        gate_frame = labels["gate-released"]["state"]
        gate_before_state = gate_row.get("state_before", {})
        closed_door_state = gate_before_state.get("doors", {}).get(door_id, {})
        before_meta = gate_row.get("before", {})
        # The supported post-open camera approach can enter an authored
        # encounter region. Preserve every prior removal in append order and
        # permit only newly witnessed source-region/key-qualified encounter IDs.
        removed_before = gate_row.get("state", {}).get("removed", [])
        removed_after = gate_frame.get("removed", [])
        _need(type(removed_before) is list and type(removed_after) is list
              and removed_after[:len(removed_before)] == removed_before
              and len(set(removed_after)) == len(removed_after),
              "Post-gate approach must preserve exact prior removal identities/order")
        additions = removed_after[len(removed_before):]
        encounters = {"encounter:"+row["id"]:row for row in scenes.get("encounters", [])}
        position = _as_vec(gate_frame.get("player_position")); cell_size = float(scenes["cell_size"])
        for marker in additions:
            encounter = encounters.get(marker)
            _need(type(encounter) is dict and len(encounter.get("region", [])) == 4,
                  "Unwitnessed non-encounter removal after gate release refused")
            x0,z0,x1,z1 = map(float, encounter["region"])
            _need(x0 <= position[0]/cell_size <= x1 and z0 <= position[2]/cell_size <= z1
                  and set(encounter.get("requires", [])) <= set(gate_frame.get("keys", [])),
                  "Post-gate encounter addition must match actual supported position and source key requirements")
        _need(gate_row.get("door") == door_id and before_meta.get("removed") is False
              and before_meta.get("dictionary_entry") is True
              and before_meta.get("closed_ray_hits_original_body") is True
              and door_id not in gate_before_state.get("removed", [])
              and closed_door_state.get("instance_id") == before_meta.get("body_instance")
              # Production Level._build_gate hides only the collision body fallback;
              # the independent GateArt cover supplies the visible closed gate.
              and closed_door_state.get("collision_layer") == before_meta.get("collision_layer") == 1
              and closed_door_state.get("visible") == before_meta.get("visible") is False
              and gate_row.get("unlock_return") is True
              and gate_row.get("after", {}).get("removed") is True
              and gate_row.get("after", {}).get("dictionary_entry") is False
              and gate_row.get("after", {}).get("actual_aperture_ray_clear") is True
              and door_id not in gate_frame.get("doors", {}) and door_id in gate_frame.get("removed", [])
              and gate_row.get("state", {}).get("doors") == gate_frame.get("doors")
              and gate_row.get("state", {}).get("keys") == gate_frame.get("keys"),
              "Fresh closed-door to open aperture must join the current serialized production state")
        _require_actor_death_joins(grant, scenes, labels, by_kind)
    elif mode == "weapon-roles":
        original = json.loads(ORIGINAL_CASES_PATH.read_bytes())
        original_row = next((row for row in original["jobs"] if row.get("id") == case["id"]), None)
        _need(type(original_row) is dict and case.get("preferred_ranges_m") == original_row.get("preferred_ranges_m"),
              "Range bins must retain the exact original 22-case contract")
        weapons = _source_weapon_specs(project, manifest)
        weapon_index = int(case["weapon"])
        _need(0 <= weapon_index < len(weapons), "Source weapon index invalid")
        weapon_spec = weapons[weapon_index]
        source_actor_ids = {str(row.get("id")) for row in scenes.get("enemies", []) if type(row) is dict and row.get("id")}
        events_for_case = by_kind.get("actual_crosshair_fire_not_redirected_portrait", [])
        _need(len(events_for_case) == 6, "All six accepted actual fire/contact traces required")
        seen = set()
        for event in events_for_case:
            weapon = int(event.get("weapon", -1)); bin_index = int(event.get("bin", -1))
            transaction = event.get("transaction")
            _need(type(transaction) is dict and transaction.get("accepted") is True
                  and weapon == weapon_index and 0 <= bin_index < 3,
                  "Accepted production fire must match case weapon and one range bin")
            reduced = bool(event.get("reduced_effects")); key = (weapon, bin_index, reduced)
            _need(key not in seen, "Duplicate/foreign weapon-role transaction"); seen.add(key)
            label = ("reduced" if reduced else "normal") + "-range-" + str(bin_index)
            frame = labels[label]
            _need(frame.get("reduced_effects") is reduced and frame.get("weapon") == weapon
                  and frame.get("subject") == transaction.get("target_actor"),
                  "Current prefire frame must join actual weapon/role target")
            expected_distance = float(case["preferred_ranges_m"][bin_index])
            arrangement = transaction.get("role_arrangement")
            _need(type(arrangement) is dict and arrangement.get("actor_id") == frame.get("subject")
                  and arrangement.get("actor_id") in source_actor_ids
                  and arrangement.get("candidate_index") == bin_index
                  and abs(float(arrangement.get("requested_distance_m", -999))-expected_distance) < 1e-5
                  and abs(float(arrangement.get("current_query_distance_m", -999))-expected_distance)
                      <= max(1.0, expected_distance*.15)
                  and _near_vec(arrangement.get("player_world"), frame.get("foot"), .002)
                  and arrangement.get("visual_query") == "current production SpriteHitQuery.cast; no forced sprite frame"
                  and arrangement.get("opaque_contact_verified") is True,
                  "Actual current target query must join the requested source range and captured player pose")
            state = frame["state"]
            event_state = event["state"]
            actor_before = _actor_state(state, arrangement["actor_id"])
            actor_after = _actor_state(event_state, arrangement["actor_id"])
            camera = _as_vec(frame.get("camera_position"))
            forward = _as_vec(frame.get("camera_forward"))
            point = _as_vec(arrangement.get("actual_crosshair_point"))
            ray_delta = [point[i]-camera[i] for i in range(3)]
            ray_distance = math.sqrt(sum(v*v for v in ray_delta))
            forward_length = math.sqrt(sum(v*v for v in forward))
            _need(ray_distance > 0 and abs(ray_distance-float(arrangement.get("current_query_distance_m",-999))) <= .03
                  and forward_length > 0
                  and sum(ray_delta[i]*forward[i] for i in range(3))/(ray_distance*forward_length) >= .9999,
                  "Captured opaque SpriteHitQuery point must lie on the measured current camera ray")
            fire_event = event
            if weapon_index == 4:
                immediate = [row for row in by_kind.get("actual_projectile_fire_immediate", [])
                             if row.get("trace_seq") == transaction.get("immediate_fire_trace_seq")]
                _need(len(immediate) == 1, "Projectile resolution must reference one actual immediate fire trace")
                fire_event = immediate[0]
                immediate_transaction = fire_event.get("transaction", {})
                _need(fire_event.get("weapon") == weapon_index and fire_event.get("bin") == bin_index
                      and fire_event.get("reduced_effects") == event.get("reduced_effects")
                      and fire_event.get("role_arrangement") == arrangement
                      and immediate_transaction == {k:v for k,v in transaction.items()
                          if k not in ("hp_after", "reduced_effects", "weapon", "bin", "immediate_fire_trace_seq")}
                      and fire_event["trace_seq"] < event["trace_seq"]
                      and 0 <= event["physics_tick"]-fire_event["physics_tick"] <= 300,
                      "Projectile delayed resolution must causally join its exact immediate accepted fire")
                immediate_state = fire_event["state"]
                _need(immediate_state.get("ammo") == event_state.get("ammo")
                      and immediate_state.get("shot_sequence") == event_state.get("shot_sequence")
                      and _near_vec(immediate_state.get("player_position"), frame.get("foot"), .002),
                      "Projectile immediate fire must carry actual post-shot counters and captured player pose")
            _need(_near_vec(event_state.get("player_position"), frame.get("foot"), .002)
                  and type(fire_event.get("physics_tick")) is int and frame.get("trace_seq",0) < fire_event.get("trace_seq",0)
                  and 0 <= fire_event["physics_tick"]-frame["physics_tick"] <= 8,
                  "Accepted shot must immediately join the same captured pre-fire player pose/tick window")
            _need(_near_vec(actor_before.get("world_position"), arrangement.get("target_world"))
                  and abs(float(actor_before.get("yaw_degrees",999))-float(arrangement.get("actor_yaw_degrees",-999))) < .01
                  and actor_before.get("sprite_frame") == arrangement.get("sprite_frame"),
                  "Serialized current target actor pose/frame does not match live SpriteHitQuery arrangement")
            in_range = float(arrangement["current_query_distance_m"]) <= weapon_spec["range"]
            _need(event.get("role_arrangement") == arrangement and frame.get("role_arrangement") == arrangement
                  and abs(float(transaction.get("range", -999))-weapon_spec["range"]) < 1e-5
                  and abs(float(transaction.get("requested_distance_m", -999))-expected_distance) < 1e-5
                  and abs(float(arrangement.get("current_query_distance_m", -999))-expected_distance)
                      <= max(1.0, expected_distance*.15),
                  "Source weapon cap and selected live crosshair range must join captured frame/fire")
            _need(int(actor_before.get("hp", -1)) == int(transaction.get("hp_before", -2))
                  and int(actor_after.get("hp", -1)) == int(transaction.get("hp_after", -2))
                  and ((transaction.get("target_actor") == transaction.get("aimed_actor")) if in_range
                       else (transaction.get("target_actor") != transaction.get("aimed_actor"))),
                  "Frame/event actor state and actual source weapon range/contact do not causally match")
            if in_range:
                damage = int(transaction["hp_before"])-int(transaction["hp_after"])
                _need(0 < damage <= weapon_spec["damage"]*weapon_spec["pellets"],
                      "In-range accepted contact must cause current actor HP loss")
                shot_contact = transaction.get("shot_contact", {})
                _need(type(shot_contact) is dict and shot_contact.get("actor_id") == arrangement.get("actor_id")
                      and shot_contact.get("coverage") == "visible_sprite"
                      and _near_vec(shot_contact.get("position"), arrangement.get("actual_crosshair_point"), .03)
                      and abs(float(transaction.get("distance",-999))-ray_distance) <= .03
                      and shot_contact.get("sprite_frame") == arrangement.get("sprite_frame")
                      and shot_contact.get("sprite_pixel") == arrangement.get("sprite_pixel")
                      and shot_contact.get("frame_pixel") == arrangement.get("frame_pixel"),
                      "Actual Player.fire opaque contact must match current frame/query, without hardcoded atlas pixel")
            else:
                _need(int(transaction["hp_after"]) == int(transaction["hp_before"]),
                      "Out-of-range fire must not manufacture actor HP loss")
            expected_ammo = 0 if weapon_index == 0 else 1
            ammo_before = int(state["ammo"][weapon_index]); ammo_after = int(event["state"]["ammo"][weapon_index])
            seq_before = int(state["shot_sequence"][weapon_index]); seq_after = int(event["state"]["shot_sequence"][weapon_index])
            _need(int(transaction["ammo_before"]) == ammo_before and int(transaction["ammo_after"]) == ammo_after
                  and int(transaction["sequence_before"]) == seq_before and int(transaction["sequence_after"]) == seq_after
                  and seq_after == seq_before+1 and ammo_before-ammo_after == expected_ammo,
                  "Serialized actual ammo/shot-sequence state does not match accepted fire")
            if case.get("role_arrangement"):
                role = case["role_arrangement"]
                _need(arrangement.get("actor_id") == role["actor_id"]
                      and arrangement.get("arrangement_id") == role["arrangement_id"]
                      and _vec_close(arrangement.get("target_world"), role["target_worker_world"])
                      and _near_xz(arrangement.get("player_world"), role["player_candidates_world"][bin_index])
                      and abs(float(arrangement.get("actor_yaw_degrees",999))-role["actor_original_yaw_degrees"]) < .01
                      and arrangement.get("source_scout_proposal_sha256") == role["source_scout_proposal_sha256"],
                      "Fresh Reliquary B candidate provenance/actor/XZ arrangement mismatch")
                support = state.get("player_support", {})
                _need(support.get("is_on_floor") is True and abs(float(support.get("root_minus_floor",999))+.025) <= .02
                      and abs(float(arrangement.get("root_minus_floor",999))+.025) <= .02
                      and abs(float(arrangement["player_world"][1])-float(role["player_candidates_world"][bin_index][1])) > .02,
                      "Supported player must be a naturally settled observation distinct from the authored seed Y")
            _need(_near_vec(actor_after.get("world_position"), actor_before.get("world_position"), .002),
                  "Accepted shot event must not silently relocate actor between frame and damage")
        _need(len(seen) == 6 and {x[2] for x in seen} == {False, True}
              and {x[1] for x in seen} == {0, 1, 2},
              "Normal/reduced three-range source-contract weapon matrix required")
    else:
        raise ContractError("Unknown capture mode")

def validate_job_context(case_id: str, *, context_path: Path, frames_dir: Path,
                         controller_path: Path, project: Path = PROJECT,
                         schema_path: Path = SCHEMA_PATH,
                         source_manifest_path: Path = SOURCE_PINS_PATH,
                         fixture_path: Path = FIXTURE_PATH,
                         producer_path: Path = PRODUCER_PATH) -> dict[str, Any]:
    """Validate the future context/trace/frame join only; never qualify pixels or a receipt."""
    schema, schema_raw = load_case_schema(schema_path)
    case = effective_case(case_for(case_id, schema))
    manifest, source_manifest_sha = verify_source_inventory(project, source_manifest_path)
    contract = build_job_contract(case_id, controller_path=controller_path, project=project,
        schema_path=schema_path, source_manifest_path=source_manifest_path,
        fixture_path=fixture_path, producer_path=producer_path)
    ctx_raw = context_path.read_bytes(); ctx = json.loads(ctx_raw)
    _need(ctx.get("BuildInfo") == contract["build_version"], "Context build identity does not match current pinned source")
    _need(ctx.get("status") == "CAPTURED_PENDING_INDEPENDENT_REVIEW"
          and ctx.get("capture_functional") is True and ctx.get("source_not_export_qualified") is True
          and ctx.get("earned_combat") is False and ctx.get("hardware_input") is False
          and ctx.get("performance_claim") is False and ctx.get("arranged") is True,
          "Source-arranged pending-review context scope required")
    _need(ctx.get("case_id") == case_id and ctx.get("mode") == case["mode"]
          and ctx.get("chapter_id") == case["scene_id"]
          and int(ctx.get("weapon", -2)) == case["weapon"]
          and int(ctx.get("expected_frames", -1)) == case["frame_count"],
          "Wrong job/case/scene/frame-count join")
    _need(ctx.get("resolution") == [640, 360] and ctx.get("actual_chapter") == case["scene_chapter"],
          "Exact native 640x360 case-scene metadata required")
    _need(ctx.get("fixture_sha256") == contract["fixture_sha256"]
          and ctx.get("producer_sha256") == contract["producer_sha256"]
          and ctx.get("capture_controller_sha256") == contract["capture_controller_sha256"]
          and ctx.get("case_contract_sha256") == contract["case_schema_sha256"]
          and ctx.get("source_manifest_sha256") == source_manifest_sha,
          "Root context provenance not joined to current producer/controller/fixture/source schema")
    _need(ctx.get("capture_contract") == {k:v for k,v in contract.items() if k != "native_imports"},
          "Context case contract differs from exact generated per-job contract")
    frames, events, motion = ctx.get("frames"), ctx.get("events"), ctx.get("motion")
    _need(type(frames) is list and len(frames) == case["frame_count"]
          and type(events) is list and type(motion) is list,
          "Typed actual frame/event/motion arrays required")
    expected_labels = case["frames"]
    _need([row.get("label") for row in frames] == expected_labels,
          "Exact ordered case-specific frame labels required")
    png_names = {path.name for path in frames_dir.glob("*.png")}
    _need(png_names == {label + ".png" for label in expected_labels},
          "Missing, foreign, or stale image file in job output")
    all_rows: list[tuple[int, int, dict[str, Any], str]] = []
    last_tick = -1; last_time = -1
    for index, frame in enumerate(frames):
        _need(type(frame) is dict and frame.get("version") == contract["build_version"],
              f"Legacy/foreign renderer version in frame {index}")
        _need(frame.get("case_id") == case_id
              and frame.get("frame_index") == index and frame.get("file") == expected_labels[index] + ".png"
              and frame.get("resolution") == [640, 360] and frame.get("scene_id") == case["scene_id"],
              f"Frame/case/scene join invalid at index {index}")
        for key in ("fixture_sha256", "producer_sha256", "capture_controller_sha256", "case_schema_sha256", "source_manifest_sha256"):
            _need(frame.get(key) == contract[key if key != "case_schema_sha256" else "case_schema_sha256"],
                  f"Frame has foreign {key}")
        image_path = frames_dir / frame["file"]
        _need(image_path.parent == frames_dir and image_path.name == frame["file"]
              and not image_path.is_symlink() and stat.S_ISREG(image_path.lstat().st_mode),
              "Resident direct child PNG path required")
        data = image_path.read_bytes()
        _need(len(data) == frame.get("bytes") and sha(data) == frame.get("PNG_sha256"),
              f"Encoded frame bytes/hash mismatch: {frame.get('file')}")
        try:
            from io import BytesIO
            from PIL import Image
            with Image.open(BytesIO(data)) as image:
                _need(image.format == "PNG" and image.size == (640, 360) and getattr(image, "n_frames", 1) == 1,
                      "Frame must decode as single resident 640x360 PNG")
                rgba = image.convert("RGBA").tobytes()
        except ContractError:
            raise
        except Exception as exc:
            raise ContractError("Frame is not a decodable resident PNG") from exc
        _need(sha(rgba) == frame.get("RGBA_sha256"), f"Decoded RGBA hash mismatch: {frame.get('file')}")
        _trace_provenance(frame, case_id, contract, f"frame {index}")
        state = frame["state"]
        _need(state.get("player_position") == frame.get("foot")
              and state.get("scene_id") == case["scene_id"]
              and type(frame.get("physics_tick")) is int and frame["physics_tick"] >= last_tick
              and type(frame.get("time_usec")) is int and frame["time_usec"] > last_time,
              f"Frame state/tick/time join failed: {frame.get('file')}")
        last_tick = frame["physics_tick"]; last_time = frame["time_usec"]
        all_rows.append((frame["trace_seq"], frame["physics_tick"], frame, "frame"))
    for event in events:
        _need(type(event) is dict and type(event.get("kind")) is str and event["kind"], "Typed causal event required")
        _trace_provenance(event, case_id, contract, "event")
        _need(type(event.get("physics_tick")) is int, "Event physics tick required")
        all_rows.append((event["trace_seq"], event["physics_tick"], event, "event"))
    for row in motion:
        _need(type(row) is dict and row.get("action"), "Typed player action/motion trace required")
        _trace_provenance(row, case_id, contract, "motion")
        _need(type(row.get("tick")) is int, "Motion physics tick required")
        all_rows.append((row["trace_seq"], row["tick"], row, "motion"))
    seqs = [item[0] for item in all_rows]
    _need(len(seqs) == len(set(seqs)) and sorted(seqs) == list(range(1, int(ctx.get("trace_sequence_final", 0)) + 1)),
          "Trace sequence has gaps, duplicates, foreign rows, or non-current context")
    timeline = sorted(all_rows)
    ticks = [tick for _, tick, _, _ in timeline]
    _need(all(type(tick) is int and tick >= 0 for tick in ticks), "Negative/untypeable physics tick in trace")
    _need(ticks == sorted(ticks), "Trace sequence does not follow monotonic physics ticks")
    # Frame/event references may not point beyond events that existed at capture time.
    for frame in frames:
        _need(frame.get("trace_event_count", -1) <= len(events)
              and frame.get("trace_motion_count", -1) <= len(motion), "Frame trace cursor exceeds job trace")
    _require_events(case, events, frames, motion, project, manifest)
    return {"status": "TRACE_CONTRACT_VALIDATION_ONLY_NOT_QUALIFICATION",
            "case_id": case_id, "frames": len(frames), "events": len(events), "motion_rows": len(motion),
            "source_dependency_count": len(manifest["source_dependencies"]),
            "art_dependency_count": len(manifest["art_resource_dependencies"]),
            "native_imports": manifest["native_imports"], "qualification": False,
            "execution_authenticated": False, "source_manifest_sha256": source_manifest_sha}
