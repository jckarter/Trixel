#include <math.h>

#define MOUSE_ROTATE_FACTOR 1.0
#define MOUSE_DISTANCE_FACTOR 1.0

#define INITIAL_DISTANCE 32.0

#define RADIANS (M_PI/180.0)
#define LIGHT_DISTANCE 500.0

typedef struct _MasonViewRotation {
    float yaw, pitch;
} MasonViewRotation;

typedef struct _MasonViewAngle {
    MasonViewRotation eye, light;
    float distance;
} MasonViewAngle;

static inline float
fbound(float x, float mn, float mx)
{
    return fmin(fmax(x, mn), mx);
}

static inline void MasonViewAngleInitialize(MasonViewAngle * a)
{
    a->eye.yaw = a->eye.pitch = 0.0;
    a->light.yaw = 210.0;
    a->light.pitch = 60.0;
    a->distance = INITIAL_DISTANCE;
}

static inline void MasonViewRotationYawPitch(MasonViewRotation * r, float yoffset, float poffset)
{
    r->yaw += yoffset * MOUSE_ROTATE_FACTOR;
    r->pitch = fbound(r->pitch + poffset * MOUSE_ROTATE_FACTOR, -90.0, 90.0);
}
