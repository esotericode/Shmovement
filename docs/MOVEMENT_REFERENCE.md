# Movement reference and implementation notes

## Sources and provenance

Research baseline: [`n64decomp/sm64` at `9921382a68bb0c865e5e45eb594d9c64db59b1af`](https://github.com/n64decomp/sm64/tree/9921382a68bb0c865e5e45eb594d9c64db59b1af), inspected 2026-09-16. The intended reference is ordinary US/N64 land movement without power-ups, environmental hazards, or speedrun glitches.

| Reference | What was examined |
| --- | --- |
| [`mario.c`](https://github.com/n64decomp/sm64/blob/9921382a68bb0c865e5e45eb594d9c64db59b1af/src/game/mario.c) | Input magnitude shaping, launch values, momentum changes, jump selection |
| [`mario_actions_moving.c`](https://github.com/n64decomp/sm64/blob/9921382a68bb0c865e5e45eb594d9c64db59b1af/src/game/mario_actions_moving.c) | Running acceleration, limited turning, reversing, braking and slopes |
| [`mario_actions_airborne.c`](https://github.com/n64decomp/sm64/blob/9921382a68bb0c865e5e45eb594d9c64db59b1af/src/game/mario_actions_airborne.c) | Air drag, longitudinal control, sideways steering and speed thresholds |
| [`mario_step.c`](https://github.com/n64decomp/sm64/blob/9921382a68bb0c865e5e45eb594d9c64db59b1af/src/game/mario_step.c) | Gravity, jump-release behavior, displacement ordering, collision substeps |
| [`sm64pc/sm64ex`](https://github.com/sm64pc/sm64ex) | Secondary context: modern controls and optional analog camera |
| [`libsm64/libsm64`](https://github.com/libsm64/libsm64) | Secondary context: separation of character simulation from a host engine |

The latter projects share decompilation ancestry. They are not independent confirmations of the original rules. Their engine code is not linked into this project. No reconstructed source files, original models, animations, textures, audio, or ROM assets are included.

This implementation was written after consulting the reconstructed source, so it must not be described as a formal clean-room implementation. The source repositories' CC0 labels are not evidence of clearance of third-party rights. This document records technical provenance; it is not a legal opinion or a licence grant for the reference projects.

## Unit convention

We choose **100 reference distance units = 1 metre**, and use **30 reference updates per second** as the US/N64 timing baseline. This is a modelling convention, not a claim about Mario's real-world size. Godot runs this prototype at **60 physics ticks per second**.

- Velocity conversion: reference units/update × 0.01 × 30 → m/s.
- Acceleration conversion: reference units/update² × 0.01 × 30² → m/s².
- Angular rate conversion: reference turn units/update × 2π / 65536 × 30 → rad/s.

Multiplying coefficients by these factors preserves their dimensions, but does not make a 60 Hz discrete simulation identical to a 30 Hz simulation. Threshold crossings, collision timing, integration order, and quantized angles still matter. Rendering interpolation is independent of the physics frequency.

## Behavioral specification used for the first pass

| Behavior | Reference observation | Godot baseline |
| --- | --- | --- |
| Analog response | Intended magnitude uses squared stick magnitude | Squared normalized stick strength after Godot's radial deadzone |
| Ordinary running | Nominal target speed 32; acceleration decreases with current forward speed | Target 9.6 m/s; acceleration 9.9 minus 0.697674 × speed |
| Initial movement | Ground entry can raise low speed toward a small input-dependent minimum | Initial speed up to 2.4 m/s |
| Turning | Ground heading changes by a bounded angle per update | Up to 5.890486 rad/s; reversal above 100° brakes first |
| Ordinary jump | Vertical launch 42 plus one quarter of forward speed; then horizontal speed × 0.8 | 12.6 m/s plus one quarter of running speed; 80% retention |
| Double / triple | Higher launch values 52 / 69; triple normally requires forward speed above 20 | 15.6 m/s + running bonus / 20.7 m/s; triple threshold 6 m/s |
| Long jump | Launch 30; forward multiplier 1.5 with positive cap 48 | 9 m/s vertical; 1.5× forward speed, bounded at 14.4 m/s |
| Ordinary gravity | Downward change 4 each update; fall limit 75 | 36 m/s², terminal speed 22.5 m/s |
| Long-jump gravity | Half ordinary gravity | Gravity multiplier 0.5 |
| Jump release | Eligible ascending jumps above speed 20 can have vertical speed quartered | Single / double jumps above 6 m/s are shortened once to 25% vertical speed |
| Air control | Small forward drag; input acts along the takeoff heading, with separate sideways movement | Forward drag 3.15 m/s²; input acceleration 13.5 m/s²; sideways velocity up to 3 m/s |
| Air overspeed | Additional drag above ordinary / long-jump thresholds | Additional 9 m/s² above 9.6 / 14.4 m/s |

The running controller is designed around heading plus forward speed. Most airborne steering does not rotate the takeoff heading, which is important to retaining a recognizable feel. It is possible to steer sideways or brake backward while still facing the takeoff direction.

Movement uses displacement before the gravity update. It does not reproduce the original four collision quarter-steps: Godot's capsule sweep and slide response owns collision resolution here.

## Explicit approximations and changes

- **Collision:** an upright 1.8 m capsule uses `CharacterBody3D.move_and_slide()`, floor snapping, a 46° walkable-slope threshold, and Godot Physics. Original wall probes, step rules, floor searches, ledge grabs, and collision glitches are not reproduced.
- **Ground friction:** braking uses explicit per-second rates. Surface classifications and the original action-specific stopping behavior have not been exhaustively matched.
- **Slopes:** the controller adds a small downhill component and uses Godot's constant-speed floor response. This is a useful testable slope model, not a reconstruction of all original slope formulas.
- **Input:** Godot's radial deadzone and modern stick mapping replace N64 controller gate geometry and integer sampling. Keyboard input is full-strength.
- **Landing chains:** a configurable 200 ms window selects single, double, and triple jumps. It does not reproduce every original landing animation, transition, or cancellation rule.
- **Wall kicks:** a direct collision-normal launch with a configurable contact window replaces the original full bonk / wall-kick state sequence. A short lockout prevents immediate repeated use of the same contact.
- **Bounds:** signed air speed has a safety cap of 16 m/s. The prototype deliberately avoids unlimited reverse long-jump speed and other runaway values.
- **Assists:** OFF by default. When enabled: 100 ms ledge grace, 120 ms jump buffering, and a 120 ms wall-contact window. These are adjustable additions.
- **Presentation:** camera, feet animation, capsule, face, room, material treatment, labels, and HUD are original.

## Next fidelity work

Establish recorded input sequences and trajectories from the chosen reference version. Compare stopping distance, angular response, tap / hold arcs, landing transitions, slopes, and wall interactions against the prototype. The existing engine tests make regressions visible, but do not substitute for this reference comparison. Extend the move set after the core measurements and playtesting agree.
