/* Test-only host boundary. World contacts are supplied by each scenario.
 * No held objects, damage, caps, wind, sand, water, rumble or audio are simulated.
 * Never link this oracle into the game. */
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <math.h>
#include <assert.h>
typedef float f32;
typedef int16_t s16;
typedef uint16_t u16;
typedef int32_t s32;
typedef uint32_t u32;
typedef uint8_t u8;
typedef float Vec3f[3];
#define UNUSED
#define TRUE 1
#define FALSE 0
#define ENABLE_RUMBLE 0
#define GRAB_POS_LIGHT_OBJ 1
#include "constants.h"
enum { AIR_STEP_NONE, AIR_STEP_LANDED, AIR_STEP_HIT_WALL, AIR_STEP_GRABBED_LEDGE,
       AIR_STEP_GRABBED_CEILING, AIR_STEP_HIT_LAVA_WALL };
enum { GROUND_STEP_LEFT_GROUND, GROUND_STEP_NONE, GROUND_STEP_HIT_WALL };
struct Surface { struct { float x,y,z; } normal; int type; };
struct Animation { int loopEnd; };
struct Object {
    struct { struct { s16 angle[3]; float cameraToObject[3];
        struct { int animID, animFrame; struct Animation *curAnim; } animInfo;
    } gfx; } header;
    int oMarioLongJumpIsSlow;
};
struct MarioBodyState { int grabPos, wingFlutter; };
struct Controller { float stickMag; };
struct Area { int terrainType; };
struct MarioState {
    u32 action, prevAction, actionArg, actionState, actionTimer, flags, input, particleFlags;
    float forwardVel, intendedMag, slideVelX, slideVelZ, vel[3], pos[3];
    float peakHeight, quicksandDepth, gettingBlownGravity;
    s16 intendedYaw, faceAngle[3], slideYaw;
    int squishTimer, wallKickTimer, terrainSoundAddend;
    struct Surface *floor, *wall;
    struct Object *marioObj, *heldObj;
    struct MarioBodyState *marioBodyState;
    struct Controller *controller;
    struct Area *area;
};
extern float gSineTable[];
extern s16 gArctanTable[];
#define sins(a) gSineTable[((u16)(a)) >> 4]
#define coss(a) gSineTable[(((u16)(a)) >> 4) + 1024]
#define play_sound(...) ((void)0)
#define play_mario_sound(...) ((void)0)
#define play_mario_jump_sound(...) ((void)0)
#define play_flip_sounds(...) ((void)0)
#define common_air_action_step(...) (assert(!"Entry-only oracle action reached air simulation"),0)
static int gSpecialTripleJump = 0;
#define play_mario_landing_sound(...) ((void)0)
#define play_mario_landing_sound_once(...) ((void)0)
#define adjust_sound_for_speed(...) ((void)0)
#define align_with_floor(...) ((void)0)
#define mario_update_moving_sand(...) ((void)0)
#define mario_update_windy_ground(...) ((void)0)
#define mario_check_object_grab(...) 0
#define mario_grab_used_object(...) ((void)0)
#define should_get_stuck_in_ground(...) 0
#define check_fall_damage(...) 0
#define check_horizontal_wind(...) 0
#define get_additive_y_vel_for_jumps() 0.0f
#define apply_twirl_gravity(...) assert(!"twirl outside oracle scope")
#define lava_boost_on_wall(...) assert(!"lava outside oracle scope")
#define vec3f_copy(d,s) memcpy(d,s,sizeof(Vec3f))
u32 set_mario_action(struct MarioState *,u32,u32);
#define drop_and_set_mario_action set_mario_action
s32 mario_get_floor_class(struct MarioState *);
s16 set_mario_animation(struct MarioState *, s32);
s32 perform_air_step(struct MarioState *,u32);
s32 perform_ground_step(struct MarioState *);
void stationary_ground_step(struct MarioState *);
