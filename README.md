# Shmovement

A Godot 4.7.2 movement playground working toward faithful **NTSC US Super Mario 64 movement**, with original controller code and a CC0 character.

**This is not yet a 1:1 recreation.** Movement runs at native 30 Hz timing. A differential harness now executes pinned original C routines and compares them with our GDScript frame by frame. Godot capsule collision, input conversion, and several action families still differ. The [fidelity document](docs/MOVEMENT_REFERENCE.md) distinguishes measured behavior from remaining work.

## Run

The **Shmovement-Godot-4.7.2** artifact in a successful [GitHub Actions run](https://github.com/esotericode/Shmovement/actions) contains a ready-to-open project and the character assets. Unzip both the artifact archive and the project archive inside it, then import `project.godot` in **Godot 4.7.2 standard** and press **F5**.

For a source checkout, fetch the character once **before opening the project**:

```sh
python3 tools/fetch_character.py
godot --editor --path .
```

The script downloads Kenney's CC0 asset pack and verifies the five used files against pinned SHA-256 hashes. Godot imports FBX directly; no Blender installation is required. No ROM or Nintendo assets are needed.

## Try these moves

| Action | Input |
| --- | --- |
| Move / look | WASD / mouse; controller left / right stick |
| Jump / control height | Space / controller bottom face button; hold or release |
| Side somersault | Run, reverse, then jump while **SIDE FLIP READY** is shown |
| Long jump | While running, press Shift / LT, then jump |
| Wall kick | Jump into a wall at speed, then press jump during the impact/recovery window |
| Backflip | Stop, crouch, then jump |
| Double / triple | Jump again promptly after landing; the third needs enough forward speed |
| Dive / attack | E / controller left face button (Xbox X); run fast enough for a ground dive |
| Air dive | Attack during a jump; slow single/double jumps kick instead; long jumps/backflips cannot dive |
| Belly-slide recovery | Jump **or** attack to roll out; steep slippery slopes block recovery |
| Practice stations | 1 basics; 2 run/dive lanes; 3 wall tower; 4 jump course; 5 slopes |
| Retry station / recenter | R / F; controller top face / left stick click |
| Experiment settings | T / controller Start |
| Experimental assists | F1; off by default |
| Release mouse | Escape |

Original input priority matters: reversing and jumping on the exact same tick produces an ordinary jump. Press crouch before jump for the initial long jump.

The **120 × 120 m** playground has three **100 m** runways with different friction classes, a **24 m** wall tower, ten ascending platforms and a finish deck, and 12°/22°/35° ramps. The earlier steps, low ceiling, paired walls, and seven-metre gap remain at station 1. Number keys teleport to a station; R retries it.

The HUD shows action, speed, surface class, dive/roll availability, side-flip availability, and remaining wall-kick ticks. The character has distinct dive, belly-slide, forward/backward rollout, and get-up poses.

## Testable parity

```sh
# Linux, Python 3, a C compiler (cc), and an imported Godot project:
python3 tools/parity/run.py /path/to/godot --self-test
# Replay a modified scenario input file:
python3 tools/parity/run.py /path/to/godot --inputs test-results/parity/inputs.json
```

Open `test-results/parity/report.html` for an interactive frame/field comparison. Inputs, original C traces, candidate traces, and a machine-readable report are saved beside it. CI publishes **source-parity-report** and includes it in the ready-to-open project.

The current suite compares **361 scenarios / 8,663 ticks**. Actions and angles must match exactly; numerical fields have an absolute tolerance of **0.0001 native units**. The self-test deliberately corrupts speed and action outputs and requires the comparator to reject them.

The oracle downloads hash-verified source at one pinned revision and compiles selected routines unchanged for testing. It supplies scripted contacts and a minimal animation clock. It does **not** run the original triangle collision solver or emulate the N64. See [the harness specification](docs/PARITY_HARNESS.md).

## What changed after the first prototype

- Separate `MovementCore` with 30 Hz actions in reference units, instead of a 60 Hz approximation.
- Explicit turnaround and finish-turn actions, with source thresholds and animation-end timing.
- Side flip: 62 units/tick up, 8 forward, facing intended direction.
- Wall impact, first-frame kick, soft/hard bonk, and an expiring recovery timer. Contact cannot refresh it.
- Original input priority, takeoff/air/gravity ordering, and uncapped air acceleration.
- A rigged Kenney character with imported idle/run/jump clips and original skid, flip, long-jump, bonk, and kick poses.
- Reference defaults preserved when opening the tuning UI. Custom settings are clearly marked as experiments.
- Dive entry, belly slide, forward/backward rollouts and a locked get-up animation.
- Full vector sliding with surface classes, slope acceleration, asymmetric steering and the original delayed speed cap.
- A compiled-source differential gate alongside engine integration tests.

## Development

```sh
python3 tools/fetch_character.py
python3 tests/validate.py /path/to/godot
```

The suite imports the project, launches it, checks **130 rule/engine/playground assertions**, and runs the compiled-source comparison. A C compiler and network access for the first reference download are required for the comparison, but not for playing. See [validation](docs/VALIDATION.md). Rendered review images are captured separately in CI.

Core code: [movement_core.gd](scripts/movement_core.gd). Godot adapter: [player.gd](scripts/player.gd). Character: [character_visual.gd](scripts/character_visual.gd).

[Movement research and remaining parity work](docs/MOVEMENT_REFERENCE.md) · [Asset provenance](THIRD_PARTY.md)
