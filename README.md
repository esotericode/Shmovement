# Shmovement

A Godot 4.7.2 movement playground working toward faithful **NTSC US Super Mario 64 movement**, with original controller code and a CC0 character.

**This is not yet a 1:1 recreation.** Selected action rules now use native 30 Hz timing and source-derived tests. Godot capsule collision, input conversion, numerical details, and several action families still differ. The [fidelity document](docs/MOVEMENT_REFERENCE.md) distinguishes implemented rules from remaining work.

## Run

The **Shmovement-Godot-4.7.2** artifact in a successful [GitHub Actions run](https://github.com/esotericode/Shmovement/actions) contains a ready-to-open project and the character assets. Unzip both the artifact archive and the project archive inside it, then import `project.godot` in **Godot 4.7.2 standard** and press **F6/F5** (F5 starts the playground).

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
| Reset / recenter | R / F; controller top face / left stick click |
| Experiment settings | T / controller Start |
| Experimental assists | F1; off by default |
| Release mouse | Escape |

Original input priority matters: reversing and jumping on the exact same tick produces an ordinary jump. Press crouch before jump for the initial long jump.

The room contains steps, a 22-degree ramp, a low ceiling, paired walls, and a seven-metre gap. The HUD shows the actual action, frame count, native forward/up velocities, facing angle, animation clock, side-flip availability, and remaining wall-kick ticks.

## What changed after the first prototype

- Separate `MovementCore` with 30 Hz actions in reference units, instead of a 60 Hz approximation.
- Explicit turnaround and finish-turn actions, with source thresholds and animation-end timing.
- Side flip: 62 units/tick up, 8 forward, facing intended direction.
- Wall impact, first-frame kick, soft/hard bonk, and an expiring recovery timer. Contact cannot refresh it.
- Original input priority, takeoff/air/gravity ordering, and uncapped air acceleration.
- A rigged Kenney character with imported idle/run/jump clips and original skid, flip, long-jump, bonk, and kick poses.
- Reference defaults preserved when opening the tuning UI. Custom settings are clearly marked as experiments.

## Development

```sh
python3 tools/fetch_character.py
python3 tests/validate.py /path/to/godot
```

The suite imports the real project, launches it, checks source-derived frame rules, and exercises actual room/collision/input behavior. See [validation](docs/VALIDATION.md). Rendered review images are captured separately in CI.

Core code: [movement_core.gd](scripts/movement_core.gd). Godot adapter: [player.gd](scripts/player.gd). Character: [character_visual.gd](scripts/character_visual.gd).

[Movement research and remaining parity work](docs/MOVEMENT_REFERENCE.md) · [Asset provenance](THIRD_PARTY.md)
