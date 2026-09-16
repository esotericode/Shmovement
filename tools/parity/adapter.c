/* A deliberately small host adapter, not a second implementation of movement.
 * Source handlers, slide/air equations, gravity, thresholds and action launch
 * initialization are compiled verbatim above this file. */
static struct MarioState m;
static struct Object obj;
static struct MarioBodyState body;
static struct Controller controller;
static struct Area area;
static struct Surface floor_surface, wall_surface;
static struct Animation animation;
static int contact;
static float displacement[3];

s32 mario_get_floor_class(struct MarioState *s) { return s->floor->type; }
u32 set_mario_action(struct MarioState *s,u32 action,u32 arg) {
    if ((action & ACT_GROUP_MASK) == ACT_GROUP_AIRBORNE)
        action = set_mario_action_airborne(s,action,arg);
    s->prevAction = s->action;
    s->action = action; s->actionArg = arg; s->actionState = 0; s->actionTimer = 0;
    return 1;
}
s16 set_mario_animation(struct MarioState *s,s32 id) {
    if (s->marioObj->header.gfx.animInfo.animID != id) {
        s->marioObj->header.gfx.animInfo.animID = id;
        s->marioObj->header.gfx.animInfo.animFrame = id == MARIO_ANIM_BACKWARD_SPINNING ? 1 : -1;
        animation.loopEnd = id == MARIO_ANIM_DIVE ? 20 : id == MARIO_ANIM_SLOW_LAND_FROM_DIVE ? 38 : 10;
    }
    return s->marioObj->header.gfx.animInfo.animFrame;
}
s32 perform_air_step(struct MarioState *s,u32 arg) {
    (void)arg;
    memcpy(displacement,s->vel,sizeof(displacement));
    apply_gravity(s);
    return contact == 1 ? AIR_STEP_LANDED : contact == 2 ? AIR_STEP_HIT_WALL : AIR_STEP_NONE;
}
s32 perform_ground_step(struct MarioState *s) {
    memcpy(displacement,s->vel,sizeof(displacement));
    return contact == 3 ? GROUND_STEP_LEFT_GROUND : contact == 2 ? GROUND_STEP_HIT_WALL : GROUND_STEP_NONE;
}
void stationary_ground_step(struct MarioState *s) {
    mario_set_forward_vel(s,0); s->vel[1]=0;
    memcpy(displacement,s->vel,sizeof(displacement));
}

void reference_reset(double *v) {
    memset(&m,0,sizeof(m)); memset(&obj,0,sizeof(obj)); memset(displacement,0,sizeof(displacement));
    m.marioObj=&obj; m.marioBodyState=&body; m.controller=&controller; m.area=&area;
    m.floor=&floor_surface; m.wall=&wall_surface;
    obj.header.gfx.animInfo.curAnim=&animation; obj.header.gfx.animInfo.animID=-1;
    m.action=(u32)v[0]; m.forwardVel=v[1]; m.vel[1]=v[2]; m.faceAngle[1]=v[3];
    m.slideYaw=v[4]; m.slideVelX=-v[5]; m.slideVelZ=-v[6];
    m.vel[0]=m.slideVelX; m.vel[2]=m.slideVelZ; m.flags=MARIO_UNKNOWN_08;
    m.faceAngle[0]=v[7];
    if (v[8]) set_mario_action(&m,(u32)v[8],0);
    if (m.action==ACT_DIVE_SLIDE) { set_mario_animation(&m,MARIO_ANIM_DIVE); obj.header.gfx.animInfo.animFrame=19; }
}

/* mode 0: full supported action; 1: slide math; 2: air math; 3: entry selection. */
void reference_step(double *v) {
    int mode=v[0];
    m.intendedYaw=v[1]; m.intendedMag=v[2]; m.input=(u32)v[3];
    controller.stickMag=sqrtf(m.intendedMag*128.0f);
    int classes[]={SURFACE_CLASS_DEFAULT,SURFACE_CLASS_SLIPPERY,SURFACE_CLASS_VERY_SLIPPERY,SURFACE_CLASS_NOT_SLIPPERY};
    floor_surface.type=classes[(int)v[4]];
    floor_surface.normal.x=-v[5]; floor_surface.normal.y=v[6]; floor_surface.normal.z=-v[7];
    wall_surface.normal.x=-v[9]; wall_surface.normal.y=v[10]; wall_surface.normal.z=-v[11];
    contact=v[8]; m.wall=contact==2 ? &wall_surface : NULL;
    if (mario_floor_is_slippery(&m)) m.input |= INPUT_ABOVE_SLIDE;
    memset(displacement,0,sizeof(displacement));
    if (mode==1) { update_sliding(&m,v[12]); memcpy(displacement,m.vel,sizeof(displacement)); return; }
    if (mode==2) { update_air_without_turn(&m); perform_air_step(&m,0); return; }
    if (mode==3) {
        if (m.action==ACT_WALKING) check_ground_dive_or_punch(&m);
        else if (m.action==ACT_WALL_KICK_AIR) act_wall_kick_air(&m);
        else if (m.action==ACT_TRIPLE_JUMP) act_triple_jump(&m);
        else if (m.action==ACT_SIDE_FLIP) act_side_flip(&m);
        else if (m.action==ACT_FREEFALL) act_freefall(&m);
        else check_kick_or_dive_in_air(&m);
        return;
    }
    for (int i=0;i<12;i++) {
        int again=0;
        switch (m.action) {
        case ACT_DIVE: again=act_dive(&m); break;
        case ACT_DIVE_SLIDE: again=act_dive_slide(&m); break;
        case ACT_FORWARD_ROLLOUT: again=act_forward_rollout(&m); break;
        case ACT_BACKWARD_ROLLOUT: again=act_backward_rollout(&m); break;
        case ACT_STOMACH_SLIDE_STOP: again=act_stomach_slide_stop(&m); break;
        default: assert(!"Unsupported oracle action; end this trace at its scope boundary");
        }
        if (!again) break;
    }
    int *frame=&obj.header.gfx.animInfo.animFrame;
    if (obj.header.gfx.animInfo.animID==MARIO_ANIM_BACKWARD_SPINNING) (*frame)--;
    else (*frame)++;
    if (*frame>=animation.loopEnd) {
        if (obj.header.gfx.animInfo.animID==MARIO_ANIM_DIVE || obj.header.gfx.animInfo.animID==MARIO_ANIM_SLOW_LAND_FROM_DIVE) *frame=animation.loopEnd-1;
        else *frame=0;
    }
    if (*frame<0 && obj.header.gfx.animInfo.animID==MARIO_ANIM_BACKWARD_SPINNING) *frame=animation.loopEnd-1;
}

void reference_read(double *v) {
    v[0]=m.action; v[1]=m.forwardVel; v[2]=m.vel[1]; v[3]=m.faceAngle[1];
    v[4]=m.slideYaw; v[5]=-m.slideVelX; v[6]=-m.slideVelZ; v[7]=m.faceAngle[0];
    v[8]=-m.vel[0]; v[9]=-m.vel[2];
    v[10]=-displacement[0]; v[11]=displacement[1]; v[12]=-displacement[2];
    v[13]=m.actionState;
}
