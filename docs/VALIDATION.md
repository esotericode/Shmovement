# Validation

Runtime: official Godot 4.7.2, standard Linux x86_64, Godot Physics, 30 physics ticks/s. Tests may render at 60 fps; simulation remains at 30 Hz.

```sh
python3 tools/fetch_character.py
python3 tests/validate.py /path/to/godot
```

The current local run passes:

| Layer | Coverage | Result |
| --- | --- | --- |
| Import / startup | Real asset import, scripts, main scene | Pass |
| Source-derived rules | Jump arcs, turnaround, input priority, finite wall kicks | 54 / 54 |
| Engine integration | Real CharacterBody3D contacts, jump chains, dives, slide/roll recovery, attack restrictions | 42 / 42 |
| Playground | Camera, mapped input, UI defaults, ramp/gap, five station spawns, surface metadata, tower collision, reachable platform | 34 / 34 |
| Original C comparison | Entry thresholds, air/slide equations, selected complete action traces | 361 / 361 scenarios; 8,663 ticks |
| Comparator self-test | Reject deliberately corrupted speed and action outputs | Pass |
| Render review | Gameplay view, expanded area, ten character poses | Captured and inspected |

The first 54 checks use manually derived expectations. The differential suite is separate: expected values come from host-compiled original C routines, with the same initial state, processed inputs and scripted contacts as the candidate. Neither layer proves original-engine collision parity.

Actions, headings, slide headings, pitch and action phase must match exactly. Numerical fields use absolute tolerance 0.0001 native units; the current maximum observed field difference is about 0.00000763 native units. This is a bounded suite result, not a bound on all possible play.

Validation rejects script/engine errors even if Godot exits with code 0. Reference downloads are pinned and hash checked; a failed download or compile fails the comparison rather than skipping it.

CI runs the complete suite, renders review images, publishes replay/report files, and bundles a project with verified CC0 assets. The bundle excludes downloaded reference C source and the compiled oracle. See [Actions](https://github.com/esotericode/Shmovement/actions) for the run associated with your commit.

See [PARITY_HARNESS.md](PARITY_HARNESS.md) for exact oracle boundaries and [MOVEMENT_REFERENCE.md](MOVEMENT_REFERENCE.md) for remaining movement work.
