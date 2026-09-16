# Shmovement

A small 3D movement playground for **Godot 4.7.2 Standard**. Original GDScript, an original capsule character with feet, and a room built entirely from editable primitives. No external assets, plugins, ROM, or .NET installation required.

## Play

1. Download this branch with **Code → Download ZIP**, then extract it, or clone the repository and check out `prototype/movement-playground`.
2. Open **Godot 4.7.2 Standard**, choose **Import**, and select `project.godot`.
3. Press **F5**. The mouse is captured for the camera; **Escape** releases it. Click the game to resume.

The project uses the Compatibility renderer and a fixed 60 Hz physics update. The editor will generate its own `.godot` cache on first import.

## Controls

| Action | Keyboard / mouse | Gamepad |
| --- | --- | --- |
| Move | WASD | Left stick |
| Look | Mouse; IJKL also work | Right stick |
| Jump | Space; hold for height, release for a short hop | A / bottom face button |
| Double / triple jump | Press jump again promptly after landing; triple needs running speed | Same |
| Long jump | Hold Shift while running, then jump | Hold LT or LB while running, then jump |
| Wall kick | Press jump during or just after airborne wall contact | Same |
| Recenter camera | F | Left-stick click |
| Reset to start | R | Y / top face button |
| Toggle input assists | F1 | Keyboard only for this prototype |
| Open / close tuning | T | Start |
| Release / capture mouse | Escape / left click | — |

Gamepad names use Xbox-style labels; Godot's standard mapped equivalents apply. Bindings are editable in **Project → Project Settings → Input Map**. Gamepad bindings are configured, but physical controller hardware has not been tested in the development environment.

## Try these first

- **Centre lane:** accelerate, release the stick, reverse direction, and compare a tapped jump with a held jump. Chain three jumps without pausing after landing.
- **Teal steps:** test 0.6, 1.2, 1.8, and 2.4 metre heights. The 22° ramp behind them tests slope contact and changes in speed.
- **Orange islands:** build speed along the raised runway and long-jump across the seven metre gap. Falling into the gap is safe.
- **Twin walls:** approach in the air, then press jump at contact to kick away.
- **Low roof:** check that hitting the ceiling cancels upward movement cleanly.

The HUD reports horizontal speed, jump state, peak height, and the previous jump's horizontal distance and airtime. **T** exposes six live movement sliders; these edits last for the current session. For persistent tuning, edit `resources/reference_profile.tres` in the Inspector. The controller duplicates that resource on startup so live tests do not overwrite the asset.

**Assists start OFF.** F1 toggles 100 ms of ledge grace, a 120 ms prelanding jump buffer, and a wider wall-contact window. These are explicit design changes, kept separate from the baseline timing.

## What this prototype is

This is a reference-informed movement study. Running acceleration, turning, takeoff momentum, speed-dependent jump launch, variable jump height, air steering, and long-jump gravity draw on documented SM64 behavior. The implementation uses its own Resource-based settings, input handling, controller structure, and Godot collisions.

It is **not yet a measured 1:1 recreation**. The integration checks validate this prototype's behavior, not equivalence to the original game. Collision geometry, physics timing, landing windows, slope handling, braking, input deadzones, and speed caps intentionally differ or remain approximate. Backflips, side flips, dives, ground pounds, ledge grabs, swimming, and moving-platform behavior are outside this first pass.

See [the movement reference](docs/MOVEMENT_REFERENCE.md) for source links, unit conversions, and deliberate differences, and [validation notes](docs/VALIDATION.md) for measured results and remaining checks.

## Project layout

| File | Purpose |
| --- | --- |
| `scenes/playground.tscn` | Main scene, lighting, camera, player, HUD |
| `scenes/room.tscn` | Editable room geometry and collision shapes |
| `scenes/player.tscn` | Capsule collider, body, feet, face |
| `scripts/player.gd` | Movement, jumps, contact handling, measurements |
| `scripts/movement_profile.gd` | Named parameters in metres and seconds |
| `resources/reference_profile.tres` | Inspector-editable baseline settings |
| `scripts/camera_rig.gd` | Orbit camera with collision-aware spring arm |
| `scripts/character_visual.gd` | Cosmetic foot animation |
| `scripts/hud.gd` | Telemetry and live tuning |
| `tests/` | Headless controller and room integration checks |

## Run checks

With Godot 4.7.2 on your path:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --fixed-fps 60 --script tests/test_movement.gd
godot --headless --path . --fixed-fps 60 --script tests/test_playground.gd
```

Or run all checks, including startup and error-log checking, with Python 3:

```sh
python3 tests/validate.py /absolute/path/to/godot
```

GitHub Actions uses the same checks and downloads the pinned official engine binary with SHA-256 verification.
