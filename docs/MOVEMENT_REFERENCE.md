# Fidelity target and evidence

## Target

NTSC US ordinary-ground movement at 30 simulation ticks per second, without caps, held objects, damage, water, or special terrain. The earlier prototype was a feel approximation; that was not the requested target. Improvements belong in an explicitly separate experiment profile after fidelity is established.

This revision implements selected source rules in original GDScript. It does **not** establish whole-game 1:1 parity.

Primary reference: n64decomp/sm64 commit `9921382a68bb0c865e5e45eb594d9c64db59b1af`. Pinning matters: ports may fix bugs, change frame rate, input, or collision. sm64ex and libsm64 are useful integration examples, but cannot automatically serve as an identical NTSC oracle.

## The two reported failures

### Turnaround side flip

[Moving actions](https://github.com/n64decomp/sm64/blob/9921382a68bb0c865e5e45eb594d9c64db59b1af/src/game/mario_actions_moving.c): `act_walking`, `analog_stick_held_back`, `act_turning_around`, `act_finish_turning_around`.

Walking enters turnaround when forward speed is **at least 16 units/tick** and the signed intended-facing angle difference is **strictly outside ±0x471C** (approximately 100 degrees). Jump is checked before that transition, so reversing and pressing A together still gives a normal jump.

Both turnaround states accept A as a side flip. On ordinary terrain the deceleration is **4 units/tick**. Crossing zero enters finish-turn with forward speed **8**, sets facing to intended direction, and executes that successor action in the same tick.

[Action initialization](https://github.com/n64decomp/sm64/blob/9921382a68bb0c865e5e45eb594d9c64db59b1af/src/game/mario.c): side flip launches with vertical speed **62**, forward speed **8**, and intended facing. It does not have the controllable-jump-height flag, so releasing A does not cut its ascent.

The finish-turn clock uses only the timing header from [anim_BC_BD.inc.c](https://github.com/n64decomp/sm64/blob/9921382a68bb0c865e5e45eb594d9c64db59b1af/assets/anims/anim_BC_BD.inc.c): part 2 starts at frame 1, ends at 18; the action checks frame 17. No Nintendo pose/keyframe data is used. The replacement visual pose is authored independently.

### Finite wall kicks

[Airborne actions](https://github.com/n64decomp/sm64/blob/9921382a68bb0c865e5e45eb594d9c64db59b1af/src/game/mario_actions_airborne.c): `common_air_action_step`, `act_air_hit_wall`, `check_wall_kick`, `act_soft_bonk`, `act_backward_air_kb`.

Qualifying airborne contact requires forward speed **greater than 16** and a sufficiently head-on wall angle. [Air quarter-step](https://github.com/n64decomp/sm64/blob/9921382a68bb0c865e5e45eb594d9c64db59b1af/src/game/mario_step.c) uses a signed wall-normal/facing difference strictly outside **±0x6000** (135 degrees). Glancing contact alone is insufficient.

For a qualifying impact on tick **N**:

| Tick | Opportunity |
| --- | --- |
| N | Impact recorded after the air step; enter AIR_HIT_WALL |
| N+1 | First-frame kick; otherwise enter soft/hard bonk and set recovery timer to 5 |
| N+2 … N+5 | Recovery kick while the decremented timer remains nonzero |
| N+6 onward | Rejected; touching the same wall does not reopen the window |

The original missing-return bug re-enters AIR_HIT_WALL within one tick. Although the condition looks like two frames, the observed NTSC firsty window is one. Shmovement encodes that outcome explicitly instead of reproducing undefined C behavior.

Wall kicks initialize vertical speed **62**, enforce a **minimum** forward speed of **24**, and preserve faster first-frame kick speed. Heading follows the reflected incoming facing, rather than always snapping to the surface normal. Missed impacts below speed 38 enter soft bonk; faster ones enter hard knockback.

The five-tick recovery timer is decremented in [update_mario_inputs](https://github.com/n64decomp/sm64/blob/9921382a68bb0c865e5e45eb594d9c64db59b1af/src/game/mario.c) before the next action handler. It is not a sliding cooldown refreshed each frame.

## Dive, belly slide and recovery

[Airborne handlers](https://github.com/n64decomp/sm64/blob/9921382a68bb0c865e5e45eb594d9c64db59b1af/src/game/mario_actions_airborne.c) and [moving handlers](https://github.com/n64decomp/sm64/blob/9921382a68bb0c865e5e45eb594d9c64db59b1af/src/game/mario_actions_moving.c) define these rules.

| Situation | Rule |
| --- | --- |
| Walking + attack | Dive if forward speed ≥29 and original stick magnitude >48 (processed intended magnitude >18); otherwise punching |
| Single/double jump + attack | Dive only above forward speed 28; otherwise jump kick |
| Triple/side/wall-kick/freefall + attack | Dive regardless of speed |
| Long jump/backflip + attack | No dive cancellation |
| Dive initialization | Add 15 forward, cap positive speed at 48; preserve vertical speed. Ground entry supplies vertical speed 20 |
| Dive descent | Pitch decreases by 0x200 after gravity when vertical speed is negative, down to -0x2AAA |
| Dive landing | Enter DIVE_SLIDE; retain horizontal slide velocity and continue the dive animation clock |
| Slide + jump or attack | Forward rollout for positive forward speed, backward otherwise; blocked on a slippery slope |
| Rollout | Vertical speed 30; normal air steering and gravity; its own landing stop |
| Natural slide stop | Speed below 8 on a non-slope and dive animation at its end; then a non-cancellable 38-frame get-up clock |
| Dive wall hit | Reflected backward knockback, not a fresh wall-kick window |

Sliding stores a full horizontal vector separately from facing. It retains sequential X/Z steering asymmetry, slope acceleration, per-class friction, the backward-input modifier, facing adjustment and delayed stored-vector speed cap. Default/slippery/very-slippery/non-slippery classes use accelerations 7/8/10/5 and base loss factors .92/.96/.98/.92.

Runtime sine values are generated mathematically and rounded to float32. Arctangent uses reference ratio-index quantization; covered air/slide operations preserve float32 rounding order. The comparator independently uses original source tables. This does not make all runtime arithmetic bit-identical.

Animation timing headers: [dive](https://github.com/n64decomp/sm64/blob/9921382a68bb0c865e5e45eb594d9c64db59b1af/assets/anims/anim_88_89.inc.c), [rollout](https://github.com/n64decomp/sm64/blob/9921382a68bb0c865e5e45eb594d9c64db59b1af/assets/anims/anim_6F_70.inc.c), [get-up](https://github.com/n64decomp/sm64/blob/9921382a68bb0c865e5e45eb594d9c64db59b1af/assets/anims/anim_5A.inc.c). Visual poses remain original.

## Simulation and scale

`MovementCore` contains action state, integer tick timers, native speeds, and 16-bit facing. `begin_tick` chooses and cancels actions, calculates intended motion, and initializes jumps. The adapter moves the body. `end_tick` applies gravity and resolves the contact result.

- 100 reference units = 1 metre.
- Native units/tick × 0.3 = Godot metres/second.
- Normal held jump starts at 42 units/tick, displaces before losing 4 each tick, and reaches 242 units on a flat unobstructed arc.
- Long jump starts at 30 vertically and loses 2 per tick.
- Walking turns by up to 0x800 per tick.
- Air drag, acceleration, and soft thresholds preserve positive uncapped air acceleration.

Rendering interpolates between 30 Hz physics ticks. The cosmetic rig does not feed transform motion back into collision. Its animation speed also does not decide gameplay windows; those use the core's canonical clock.

## What the tests establish

[Fixtures](../tests/fixtures/ntsc_rules.json) are **manually derived from the cited rules**, not captured from a running SM64 executable. They check ordinary jump displacement, turnaround speed/state traces, strict angle/speed boundaries, initial input priority, firsty and recovery timing, expired-contact rejection, and launch values.

Engine tests separately exercise real capsule contacts, chained takeoffs, room geometry, camera, controls, UI defaults, and loading the character rig. Passing either suite is not proof of the other layer's equivalence to SM64.

The new [compiled-source harness](PARITY_HARNESS.md) independently compares dives, slide math, air math, attack entry and selected recovery transitions: 361 scenarios and 8,663 ticks. It uses scripted contacts and a host animation clock, so it does not establish collision or full animation-scheduler equivalence.

## Remaining parity work

| Area | Current state | Required for a 1:1 claim |
| --- | --- | --- |
| Turnaround and wall action windows | Source-derived rules and frame-boundary tests | Differential replay against a runnable reference |
| Collision | Godot CharacterBody3D capsule, continuous slide, floor snap | Original four quarter-steps; separate floor/ceiling/wall probes, triangle selection, radii/offsets, edge and ledge rules |
| Numerical behavior | Float32 ordering for covered air/slide math; ratio-quantized atan; original-table comparison | Extend to all actions and positions; N64 numerical edge cases |
| Controller input | Modern radial deadzone + quadratic magnitude, camera-relative | N64 raw-axis processing and camera yaw reproduction; calibrated device mapping |
| Slopes/sliding | Four surface classes and full vector equations, source comparison and practice lanes | Automatic steep-floor/downhill transitions and original surface queries |
| Landing/stationary actions | Basic landing chain and stop states | Complete previous-action distinctions, original stop-animation clocks and special landing branches |
| Dive/recovery | Source-compared dive, belly-slide and rollout subset | Original contacts, damage/stuck/object branches; complete rollout landing behavior |
| Combat/ground knockback | Simple punch fallback and ground-bonk recovery; jump-kick movement | Original punch sequence, complete ground-knockback friction and animation gates; these remain approximations |
| Other moves | Normal/double/triple/long/side/wall jumps and a basic backflip | Ground pound, crawling, ledge grab/climb, steep jumps, slide kick, swimming and any other agreed scope |
| Camera | Independent modern orbit camera | Original camera behavior if it is part of the final target |
| Visuals | CC0 humanoid, imported locomotion, original action poses | Playtesting and animation polish; no claim of original pose fidelity |

## Next acceptance gate

The first action/math differential harness is implemented. Next, extend it to the original quarter-step collision solver and feed both implementations identical processed inputs and original test triangles. Compare resolved positions, contacts, previous action, timers and complete animation clocks in addition to current fields.

Cover standing/running/tap jumps; both reversal boundaries; early/late/corner wall impacts; slope classes; ledges and ceilings; landing chains; and every newly implemented action. Set explicit tolerances for coordinates while requiring exact actions and integer timers. Only then describe covered scenarios as matching; broaden the claim as coverage grows.
