"""Run the original C routines and the Godot controller on identical test inputs.

Usage: python3 tools/parity/run.py /path/to/godot [--self-test]
Outputs replayable inputs, both traces, JSON and an interactive HTML report.
"""
import argparse
import copy
import ctypes
import html
import json
import math
import random
import re
import subprocess
from pathlib import Path
from build_reference import build, CACHE, COMMIT, FUNCTIONS, ROOT

FIELDS = ["action", "forward", "vertical", "facing", "slide_yaw", "slide_x", "slide_z",
          "pitch", "velocity_x", "velocity_z", "travel_x", "travel_y", "travel_z", "action_phase"]
EXACT = {0, 3, 4, 7, 13}
TOLERANCE = 0.0001  # Native units: 0.000001 m/tick, not a percentage tolerance.
ALIASES = {"WALL_KICK": "WALL_KICK_AIR", "PUNCH": "MOVE_PUNCHING", "HARD_BONK": "BACKWARD_AIR_KB",
           "ROLLOUT_LAND": "FREEFALL_LAND_STOP"}
SUPPORTED = {"DIVE", "DIVE_SLIDE", "FORWARD_ROLLOUT", "BACKWARD_ROLLOUT", "STOMACH_SLIDE_STOP"}

def frame(yaw=0, magnitude=32, surface=0, normal=(0, 1, 0), contact=0, wall=(0, 0, 1), stop=8, **buttons):
    return dict(input=dict(yaw=yaw, magnitude=magnitude, **buttons), surface=surface,
                normal=normal, contact=contact, wall=wall, stop=stop)

def case(name, action="DIVE", speed=32, up=20, facing=0, mode=0, frames=None, launch=None, slide=None):
    # Independently create initial native state; no candidate code is used here.
    angle = ((facing & 65535) >> 4) * math.tau / 4096
    initial = dict(action=action, speed=speed, up=up, facing=facing, slide_yaw=facing,
                   slide=slide or [-math.sin(angle) * speed, -math.cos(angle) * speed])
    if launch:
        initial["launch"] = launch
    return dict(name=name, mode=mode, initial=initial, frames=frames or [frame()])

def scenarios():
    cases = []
    for speed in [0, 27.999, 28, 28.001, 28.999, 29, 32, 48, 100]:
        for mag in [0, 18, 18.001, 32]:
            for action in ["WALKING", "JUMP", "DOUBLE_JUMP", "WALL_KICK", "TRIPLE_JUMP", "SIDE_FLIP", "FREEFALL"]:
                cases.append(case(f"entry/{action}/{speed}/{mag}", action, speed, 34, mode=3,
                                  frames=[frame(magnitude=mag, attack=True)]))
    for surface in range(4):
        for yaw in [0, 16384, -16384, -32768]:
            cases.append(case(f"slide/surface-{surface}/steer-{yaw}", "DIVE_SLIDE", 48, 0, mode=1,
                              frames=[frame(yaw=yaw, surface=surface) for _ in range(90)]))
    for speed in [-150, -32, 0, 7.999, 8, 8.001, 99.9, 140, 1000]:
        cases.append(case(f"slide/limit-{speed}", "DIVE_SLIDE", speed, 0, mode=1,
                          frames=[frame(yaw=-32768) for _ in range(30)]))
    # Test the -0x4000 facing hole and all quadrants, plus seeded changing inputs.
    rng = random.Random(640030)
    for i in range(48):
        facing = rng.randrange(-32768, 32768)
        degrees = [0, 5, 10, 15, 20, 22, 35][i % 7]
        slope_yaw = rng.random() * math.tau
        angle = math.radians(degrees)
        normal = (math.sin(angle) * math.sin(slope_yaw), math.cos(angle), math.sin(angle) * math.cos(slope_yaw))
        frames = [frame(yaw=rng.randrange(-32768, 32768), magnitude=rng.choice([0, 8, 18, 32]),
                        surface=i % 4, normal=normal) for _ in range(90)]
        cases.append(case(f"slide/seeded-{i:02d}", "DIVE_SLIDE", rng.uniform(20, 130), 0, facing, 1, frames))
    for direction in [16384, -16384]:
        cases.append(case(f"slide/perpendicular-{direction}", "DIVE_SLIDE", 32, 0, direction, 1,
                          [frame(magnitude=0) for _ in range(12)], slide=[0, -32]))
    for i in range(24):
        cases.append(case(f"air/seeded-{i:02d}", "DIVE" if i % 2 else "LONG_JUMP", rng.uniform(-40, 100),
                          rng.uniform(-80, 69), rng.randrange(-32768, 32768), 2,
                          [frame(yaw=rng.randrange(-32768, 32768), magnitude=rng.choice([0, 16, 32])) for _ in range(90)]))
    # Whole action traces. Contacts are supplied identically, not inferred from Godot.
    cases.append(case("action/dive-slide-get-up", "WALKING", 32, 20, launch="DIVE",
                      frames=[frame(contact=1 if i == 10 else 0, magnitude=32 if i < 11 else 0) for i in range(100)]))
    for recovery in ["pressed", "attack"]:
        cases.append(case(f"action/dive-slide-roll/{recovery}", "WALKING", 32, 20, launch="DIVE",
                          frames=[frame(contact=1 if i in [10, 28] else 0, **{recovery: i == 11}) for i in range(29)]))
    cases.append(case("action/backward-roll", "DIVE_SLIDE", -32, 0,
                      frames=[frame(magnitude=0, pressed=i == 0, contact=1 if i == 18 else 0) for i in range(19)]))
    cases.append(case("action/dive-wall-bonk", "FREEFALL", 32, 30, launch="DIVE",
                      frames=[frame(contact=2 if i == 4 else 0) for i in range(5)]))
    cases.append(case("action/slide-wall-bonk", "DIVE_SLIDE", 48, 0, frames=[frame(contact=2)]))
    cases.append(case("action/slow-slide-wall-stop", "DIVE_SLIDE", 10, 0, frames=[frame(contact=2)]))
    cases.append(case("action/slide-off-ledge", "DIVE_SLIDE", 48, 0, frames=[frame(contact=3)]))
    cases.append(case("action/slippery-wall-reflection", "DIVE_SLIDE", 48, 0,
                      frames=[frame(surface=2, normal=(0, math.cos(.3), math.sin(.3)), contact=2 if i == 8 else 0) for i in range(30)]))
    cases.append(case("action/steep-slide-blocks-roll", "DIVE_SLIDE", 48, 0,
                      frames=[frame(surface=2, normal=(0, math.cos(.3), math.sin(.3)), pressed=True) for _ in range(10)]))
    return cases

def reference(cases, library):
    definitions = dict((n, int(v, 16)) for n, v in re.findall(r"#define ACT_(\w+)\s+(0x[0-9A-Fa-f]+)", (CACHE / "sm64.h").read_text()))
    action_ids = {name: definitions[ALIASES.get(name, name)] for name in set(definitions) | set(ALIASES)}
    names = {v: k for k, v in definitions.items()}
    for alias, name in ALIASES.items():
        names[definitions[name]] = alias
    oracle = ctypes.CDLL(str(library))
    array = ctypes.c_double * 16
    for function in [oracle.reference_reset, oracle.reference_step, oracle.reference_read]:
        function.argtypes = [ctypes.POINTER(ctypes.c_double)]
    output = []
    for test in cases:
        s = test["initial"]
        oracle.reference_reset(array(action_ids[s["action"]], s["speed"], s["up"], s["facing"], s["slide_yaw"],
                                     *s["slide"], s.get("pitch", 0), action_ids[s["launch"]] if "launch" in s else 0))
        trace = []
        for tick, f in enumerate(test["frames"]):
            controls = f["input"]
            flags = int(controls["magnitude"] > 0)
            flags |= 2 if controls.get("pressed") else 0
            flags |= 128 if controls.get("held") else 0
            flags |= 8192 if controls.get("attack") else 0
            oracle.reference_step(array(test["mode"], controls["yaw"], controls["magnitude"], flags,
                                        f["surface"], *f["normal"], f["contact"], *f["wall"], f["stop"]))
            result = array()
            oracle.reference_read(result)
            row = list(result)[:len(FIELDS)]
            row[0] = names[int(row[0])]
            trace.append(row)
            if test["mode"] == 0 and row[0] not in SUPPORTED:
                test["frames"] = test["frames"][:tick + 1]
                break
        output.append(dict(name=test["name"], trace=trace))
    return output

def compare(expected, actual):
    errors, maximum = [], 0.0
    if [x["name"] for x in expected] != [x["name"] for x in actual]:
        raise ValueError("Candidate scenario names/order differ")
    for ref, candidate in zip(expected, actual):
        if len(ref["trace"]) != len(candidate["trace"]):
            raise ValueError(f"Missing candidate frames: {ref['name']}")
        for tick, (a, b) in enumerate(zip(ref["trace"], candidate["trace"])):
            if len(a) != len(b):
                raise ValueError("Candidate field count differs")
            for field, (x, y) in enumerate(zip(a, b)):
                delta = 0 if field in EXACT else abs(x - y)
                if field not in EXACT and (not math.isfinite(y) or not math.isfinite(x)):
                    delta = math.inf
                maximum = max(maximum, delta)
                if (x != y if field in EXACT else delta > TOLERANCE):
                    errors.append(dict(scenario=ref["name"], tick=tick, field=FIELDS[field], expected=x, actual=y))
                    break
            # Keep the first divergence per scenario so the report stays useful.
            if errors and errors[-1]["scenario"] == ref["name"]:
                break
    return errors, maximum

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("godot")
    parser.add_argument("--inputs", type=Path, help="Replay an edited inputs.json from an earlier run")
    parser.add_argument("--self-test", action="store_true", help="Verify the comparator rejects a deliberately corrupted trace")
    args = parser.parse_args()
    cases = json.loads(args.inputs.read_text()) if args.inputs else scenarios()
    library = build()
    expected = reference(cases, library)
    dest = ROOT / "test-results" / "parity"
    dest.mkdir(parents=True, exist_ok=True)
    (dest / "inputs.json").write_text(json.dumps(cases))
    (dest / "reference.json").write_text(json.dumps(expected))
    run = subprocess.run([args.godot, "--headless", "--path", str(ROOT), "--script", "tests/run_parity.gd", "--",
                          str(dest / "inputs.json"), str(dest / "candidate.json")], capture_output=True, text=True, timeout=90)
    if run.returncode or re.search(r"SCRIPT ERROR:|(?:^|\n)ERROR:", run.stdout + run.stderr):
        raise RuntimeError(run.stdout + run.stderr)
    actual = json.loads((dest / "candidate.json").read_text())
    errors, maximum = compare(expected, actual)
    if args.self_test:
        corrupted = copy.deepcopy(expected)
        corrupted[0]["trace"][0][1] += 1
        found, _ = compare(expected, corrupted)
        assert found and found[0]["field"] == "forward", "Comparator failed to detect a speed mutation"
        corrupted = copy.deepcopy(expected)
        corrupted[0]["trace"][0][0] = "WRONG_ACTION"
        assert compare(expected, corrupted)[0], "Comparator failed to detect a state mutation"
    report = dict(reference_commit=COMMIT, scenarios=len(cases), ticks=sum(len(x["trace"]) for x in expected),
                  passed=len(cases)-len(errors), tolerance_native_units=TOLERANCE, max_numeric_error=maximum,
                  errors=errors, routines=FUNCTIONS,
                  scope="Host-compiled original routines; identical scripted contacts. Does not validate the N64 CPU or triangle collision solver.")
    (dest / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    payload = json.dumps(dict(report=report, expected=expected, actual=actual, fields=FIELDS)).replace("</", "<\\/")
    template = (Path(__file__).parent / "report.html").read_text()
    (dest / "report.html").write_text(template.replace("/*DATA*/", payload))
    print(f"SOURCE COMPARISON: {report['passed']}/{report['scenarios']} scenarios; {report['ticks']} ticks; tolerance {TOLERANCE} native units")
    for error in errors[:16]:
        print(f"FAIL {error['scenario']} tick {error['tick']}: {error['field']} reference={error['expected']} candidate={error['actual']}")
    print(f"Interactive report: {dest / 'report.html'}")
    return bool(errors)

if __name__ == "__main__":
    raise SystemExit(main())
