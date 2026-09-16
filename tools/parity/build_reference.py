"""Compile untouched, pinned reference routines into a TEST-ONLY shared library.

The downloaded source stays in the ignored build directory. No ROM is needed.
The C shim specifies the omitted world/audio/object systems explicitly.
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import urllib.request

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
CACHE = ROOT / "build" / "reference"
COMMIT = "9921382a68bb0c865e5e45eb594d9c64db59b1af"
FUNCTIONS = {
    "math_util.c": ["approach_f32", "atan2_lookup", "atan2s"],
    "mario.c": ["mario_set_forward_vel", "set_mario_y_vel_based_on_fspeed",
                "set_mario_action_airborne", "mario_floor_is_slope", "mario_floor_is_slippery",
                "is_anim_at_end", "is_anim_past_end"],
    "mario_step.c": ["should_strengthen_gravity_for_jump_ascent", "apply_gravity", "mario_bonk_reflection"],
    "mario_actions_airborne.c": ["update_air_without_turn", "check_kick_or_dive_in_air",
                "act_wall_kick_air", "act_triple_jump", "act_side_flip", "act_freefall",
                "act_dive", "act_forward_rollout", "act_backward_rollout"],
    "mario_actions_moving.c": ["update_sliding_angle", "update_sliding", "check_ground_dive_or_punch",
                "slide_bonk", "common_slide_action", "act_dive_slide"],
    "mario_actions_object.c": ["animated_stationary_ground_step", "act_stomach_slide_stop"],
}

def extract(source, name):
    match = re.search(r"^[\w *]+\b" + re.escape(name) + r"\([^;]*?\)\s*\{", source, re.M)
    if not match:
        raise ValueError(f"Missing reference routine: {name}")
    start = match.start()
    end = source.index("{", start) + 1
    depth = 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start:end]

def build():
    CACHE.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((HERE / "sources.json").read_text())
    for entry in manifest["files"]:
        dest = CACHE / Path(entry["path"]).name
        if not dest.exists():
            url = f"https://raw.githubusercontent.com/n64decomp/sm64/{COMMIT}/{entry['path']}"
            data = urllib.request.urlopen(url, timeout=40).read()
            if hashlib.sha256(data).hexdigest() != entry["sha256"]:
                raise ValueError(f"Reference checksum mismatch: {entry['path']}")
            dest.write_bytes(data)
        if hashlib.sha256(dest.read_bytes()).hexdigest() != entry["sha256"]:
            raise ValueError(f"Cached reference checksum mismatch: {dest}")
    defines = []
    for name in ["sm64.h", "surface_terrains.h"]:
        defines.extend(line for line in (CACHE / name).read_text().splitlines()
                       if re.match(r"#define (ACT_|INPUT_|MARIO_|PARTICLE_|SURFACE_|TERRAIN_|GRAB_POS_)\w+\s", line)
                       and not line.rstrip().endswith("\\"))
    (CACHE / "constants.h").write_text("\n".join(defines) + "\n" + (CACHE / "mario_animation_ids.h").read_text())
    routines = []
    for filename, names in FUNCTIONS.items():
        source = (CACHE / filename).read_text()
        for name in names:
            body = extract(source, name)
            routines.append(f'\n#line {source[:source.index(body)].count(chr(10)) + 1} "{filename}"\n' + body)
    # Forward declarations are generated; the actual function bodies are unchanged.
    declarations = "\n".join(re.sub(r"\s*\{.*", ";", extract((CACHE / f).read_text(), n), count=1, flags=re.S)
                             for f, names in FUNCTIONS.items() for n in names)
    combined = '#include "shim.h"\n#include "trig_tables.inc.c"\n' + declarations
    combined += "\n" + "\n".join(routines) + '\n#include "adapter.c"\n'
    source_path = CACHE / "reference.c"
    source_path.write_text(combined)
    library = CACHE / "reference.so"
    subprocess.run(["cc", "-shared", "-fPIC", "-std=c99", "-O0", "-ffp-contract=off", "-fwrapv",
                    "-DAVOID_UB", "-Werror=implicit-function-declaration", "-I", str(HERE), "-I", str(CACHE),
                    str(source_path), "-lm", "-o", str(library)], check=True)
    return library

if __name__ == "__main__":
    print(build())
