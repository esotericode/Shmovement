# Validation

Runtime: official Godot 4.7.2, standard Linux x86_64, Godot Physics, 30 physics ticks/s. The headless tests render at a fixed 60 fps; that does not change the 30 Hz simulation.

Run:
```sh
python3 tools/fetch_character.py
python3 tests/validate.py /path/to/godot
```

- Source-derived rule suite: 54 checks. These are manually derived expectations, not recorded reference-executable traces.
- Engine movement suite: 33 checks including real turnaround side-flip takeoff and wall-kick timing boundaries.
- Actual playground suite: 17 checks including camera/input, ramp/gap, UI defaults, and humanoid rig import.
- Import and scene startup fail on script or engine errors, including errors accompanied by exit code 0.
- CI captures rendered character poses and a room overview as a separate review artifact, then bundles a project with verified CC0 assets.

Before the workspace connection failed, 54 source-rule checks, 28 earlier engine checks, and 15 earlier room checks passed locally. The additional boundary/rig checks and recovered files are validated by the latest linked GitHub Actions run. Rendered screenshots require visual review; successful capture alone is not animation-quality approval.

Observed local flat-ground measurements after moving to 30 Hz:
- Standing held jump peak: 2.4204 m (source recurrence: 2.42 m).
- Running jump peak: 3.3565 m; range: 8.4405 m.
- Long jump peak: 2.4000 m; range: 15.8305 m.
- Triple jump peak: 6.3002 m.

Small contact offsets come from Godot's collision margin. These measurements characterize this build and are not a claim of full SM64 parity. Remaining gaps and the differential replay gate are in [MOVEMENT_REFERENCE.md](MOVEMENT_REFERENCE.md).
