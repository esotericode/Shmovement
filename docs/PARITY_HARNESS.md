# Compiled-source comparison

Given the same native state, processed input and contact result, does our movement core produce the same next state? This harness answers that for a growing subset of actions. Expected outputs come from original routines, not another hand-written set of equations.

## How it works

1. `sources.json` pins n64decomp/sm64 revision `9921382a68bb0c865e5e45eb594d9c64db59b1af` and SHA-256 hashes for every downloaded file.
2. `build_reference.py` extracts selected complete C function bodies mechanically, without rewriting them. It compiles them with the original trig tables, 32-bit floats, disabled floating-point contraction, and a small host adapter. `AVOID_UB` makes sine/cosine table indexing contiguous without changing the values.
3. `run.py` constructs boundary cases and deterministic seeded input streams. The C routines produce reference traces. Expected values are never passed into Godot.
4. `tests/run_parity.gd` runs the actual `MovementCore` on the same inputs and records candidate output.
5. The comparator requires exact actions/angles/phases and a fixed absolute numerical tolerance. It reports the first divergent tick and field for every failed scenario.

Files are written to `test-results/parity/`: `inputs.json`, `reference.json`, `candidate.json`, `report.json`, and `report.html`. The HTML report works offline; choose a scenario, field and tick to inspect both traces.

```sh
python3 tools/parity/run.py /path/to/godot --self-test
python3 tools/parity/run.py /path/to/godot --inputs my_replay.json
```

Use the generated inputs as the format for a new replay. Mode 0 executes supported action handlers; mode 1 isolates slide equations; mode 2 isolates air equations plus gravity; mode 3 checks attack-entry selection. Complete-action traces stop at the first action outside the supported set, including that transition tick. They do not invent behavior for the next action.

## Current measurements

361 scenarios, 8,663 ticks. Cases include:

- Ground-dive speed 29 and processed-stick magnitude 18 boundaries; ordinary jump/double-jump speed 28 boundary; unconditional dive from wall kick/triple/side/freefall.
- Four surface classes, forward/back/side steering, seeded changing inputs and sloped normals.
- Positive and negative high-speed sliding, the delayed 100-unit stored-vector cap, and the perpendicular-facing branch.
- Dive ascent/descent pitch, landing to belly slide, forward/backward rollouts, stationary get-up, walls and leaving a ledge.
- Steep/slippery ground blocking rollout, and slippery wall reflection.

Recorded fields: action, forward/vertical velocity, facing, slide heading and velocity, dive pitch, horizontal velocity, commanded displacement and action phase. Exact matching applies to discrete fields. Float tolerance is 0.0001 native units (one millionth of a metre of per-tick displacement).

## What the adapter supplies

`shim.h` and `adapter.c` are test infrastructure authored for this project. They supply:

- Minimal state structures and surface-class metadata.
- Predetermined air/ground contact results and wall/floor normals. Commanded displacement is captured before gravity; it is not a reference collision-resolved position.
- An animation clock using timing headers: dive 20 frames, get-up 38, rollout 10; backward rollout runs backward. No pose tracks are used. Animation loading/render traversal are not emulated.
- A reduced action setter invoking original airborne initialization. Supported moving-action transitions do not need the omitted walking/sliding initialization branches.
- No-op sound/render hooks; no objects, fall damage, caps, sand, wind, water or lava. Unsupported simulated entry-only actions assert instead of pretending to be implemented.

A green report establishes agreement with these host-compiled routines under these supplied conditions. It is not proof of original ROM/N64 machine execution, animation-scheduler parity, arbitrary input streams, complete action coverage or triangle collision parity.

The game contains an original GDScript controller. Downloaded reference source stays in ignored `build/reference/`, is never linked into the game, and is excluded from project artifacts.

## Next extension

Add original floor/ceiling/wall queries and quarter-step collision to the oracle, using small original triangle fixtures. Compare resolved positions and contact/action outcomes on slopes, corners, ledges, ceilings and repeated wall kicks. Replace or adjust the Godot adapter against those failures. Extend complete-action traces to turnaround, landing chains and remaining moves before making a broader parity claim.
