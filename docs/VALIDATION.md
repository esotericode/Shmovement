# Prototype validation

Engine: **Godot 4.7.2 stable**, official Linux x86_64 build `ed1daf0bf`. Physics: **Godot Physics, 60 Hz**. Assists: **off**, except the dedicated assist tests.

## Completed checks

- Project import and script compilation.
- Startup of the actual playground scene.
- **28 controller integration checks** using the real capsule and physics engine: floor contact, running, braking, analog response, reversal, tap / hold jumps, momentum retention, running-height bonus, double / triple chaining, long jumps, ceilings, wall kicks, assist toggles, respawn, and finite state.
- **15 playground integration checks** covering the actual room: spawn, camera exclusion and wall retraction, mapped camera-relative input, tuning panel bounds and interaction, restoration of settings, ramp contact, and a successful traversal of the seven metre gap.

Use `python3 tests/validate.py /path/to/godot` to repeat the complete suite. It fails on engine error messages even if the engine happens to return exit code zero. The integration runners use `--fixed-fps 60` to advance reproducible input sequences quickly; they still execute Godot's normal physics callbacks and collision queries.

## Measured baseline

Values below come from the headless controller integration runner on a flat test surface. Horizontal input is held throughout the running and long-jump cases. They describe **this prototype**, not measurements of Super Mario 64.

| Measurement | Result |
| --- | ---: |
| Running speed | 9.60 m/s |
| Stopping distance from running speed | 2.48 m |
| Standing held-jump peak | 2.31 m |
| Tap-jump peak, released after two physics ticks | 0.74 m |
| Running held-jump peak | 3.25 m |
| Running held-jump distance | 8.42 m |
| Triple-jump peak | 6.13 m |
| Long-jump peak | 2.33 m |
| Long-jump distance | 15.59 m |

The room test also verifies that a long jump from the orange runway lands on the opposite raised island. That test exposed an undersized landing island; the destination was extended while preserving the seven metre gap.

## Remaining validation

- Rendered visual inspection on a desktop. A graphical display could not be initialized in the development environment; the automated runs were headless. HUD layout bounds and camera collision were tested numerically, but that does not verify appearance or shader rendering.
- Side-by-side input / trajectory comparison with the intended original-game version.
- Human playtesting of feel, camera comfort, and jump-chain timing.
- Physical gamepad hardware, stick calibration, and different operating systems.
- Moving platforms, unusually steep surfaces, and combinations outside this room.

The successful checks establish a working foundation. They do not establish a 1:1 match to the original game's movement or collision behavior.
