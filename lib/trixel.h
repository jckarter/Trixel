#ifndef _TRIXEL_H_
#define _TRIXEL_H_

#include <GL/glew.h>
#include <stdbool.h>
#include <stdint.h>

// Shader flags:
enum trixel_shader_flags {
    TRIXEL_SAVE_COORDINATES = 1,
    TRIXEL_SURFACE_ONLY     = 2,
    TRIXEL_LIGHTING         = 4,
    TRIXEL_SMOOTH_SHADING   = 8
};

enum trixel_light_params {
    TRIXEL_LIGHT_PARAM_POSITION = 0,
    TRIXEL_LIGHT_PARAM_AMBIENT  = 1,
    TRIXEL_LIGHT_PARAM_DIFFUSE  = 2
};

struct point3 {
    float x, y, z;
};
struct int3 {
    int x, y, z;
};

static inline struct point3 POINT3(float x, float y, float z)
    { return (struct point3){x, y, z}; }
static inline struct int3 INT3(int x, int y, int z)
    { return (struct int3){x, y, z}; }
static inline struct int3 INT3_OF_POINT3(struct point3 p)
    { return (struct int3){p.x, p.y, p.z}; }
static inline struct point3 POINT3_OF_INT3(struct int3 p)
    { return (struct point3){p.x, p.y, p.z}; }

#define POINT_ARITHMETIC_FUNCTIONS(type) \
static inline struct type add_##type(struct type a, struct type b) \
    { return (struct type){ a.x + b.x, a.y + b.y, a.z + b.z }; } \
static inline struct type sub_##type(struct type a, struct type b) \
    { return (struct type){ a.x - b.x, a.y - b.y, a.z - b.z }; } \
static inline struct type min_##type(struct type a, struct type b) \
    { return (struct type){ \
        (a.x < b.x ? a.x : b.x), \
        (a.y < b.y ? a.y : b.y), \
        (a.z < b.z ? a.z : b.z) \
    }; } \
static inline void add_to_##type(struct type * a, struct type b) \
    { a->x += b.x; a->y += b.y; a->z += b.z; } \
static inline void sub_from_##type(struct type * a, struct type b) \
    { a->x -= b.x; a->y -= b.y; a->z -= b.z; } \
static inline bool in_##type(struct type bound, struct type p) \
    { return p.x >= 0 && p.y >= 0 && p.z >= 0 && p.x < bound.x && p.y < bound.y && p.z < bound.z; } \
static inline bool eq_##type(struct type a, struct type b) \
    { return a.x == b.x && a.y == b.y && a.z == b.z; }

POINT_ARITHMETIC_FUNCTIONS(point3)
POINT_ARITHMETIC_FUNCTIONS(int3)

typedef void * trixel_state;

typedef struct voxmap {
    struct int3 dimensions;
    uint8_t data[0];
} voxmap;

typedef struct trixel_brick {
    struct point3 dimensions, dimensions_inv, normal_translate, normal_scale;
    GLuint palette_texture, voxmap_texture, normal_texture, vertex_buffer, num_vertices;
    trixel_state t;
    uint8_t palette_data[256*4];
    voxmap v;
} trixel_brick;

static inline uint8_t * trixel_brick_voxel(trixel_brick * b, int x, int y, int z)
    { return &b->v.data[x + y * b->v.dimensions.x + z * b->v.dimensions.x * b->v.dimensions.y]; }
static inline uint8_t * trixel_brick_palette_color(trixel_brick * b, int color)
    { return &b->palette_data[color * 4]; }
static inline size_t trixel_brick_voxmap_size(trixel_brick const * b)
    { return b->v.dimensions.x * b->v.dimensions.y * b->v.dimensions.z; }

trixel_state trixel_state_init(char const * resource_path, char * * out_error_message);
bool trixel_init_glew(char * * out_error_message);
trixel_state trixel_init_opengl(char const * resource_path, int viewport_width, int viewport_height, int shader_flags, char * * out_error_message);
void trixel_reshape(trixel_state t, int viewport_width, int viewport_height);
int trixel_update_shaders(trixel_state t, int shader_flags, char * * out_error_message);

void trixel_finish(trixel_state t);

trixel_brick * trixel_read_brick(void const * data, size_t data_length, char * * out_error_message);
trixel_brick * trixel_make_solid_brick(int w, int h, int d, char * * out_error_message);
trixel_brick * trixel_make_empty_brick(int w, int h, int d, char * * out_error_message);
trixel_brick * trixel_copy_brick(trixel_brick const *brick, char * * out_error_message);
void trixel_free_brick(trixel_brick * brick);
void * trixel_write_brick(trixel_brick * brick, size_t * out_data_length);

// NB: these don't call trixel_update_brick_textures for you!
unsigned trixel_optimize_brick_palette(trixel_brick * brick);
uint8_t * trixel_insert_brick_palette_color(trixel_brick * brick, int color);
void trixel_remove_brick_palette_color(trixel_brick * brick, int color);

void trixel_prepare_brick(trixel_brick * brick, trixel_state t);
void trixel_unprepare_brick(trixel_brick * brick);
bool trixel_is_brick_prepared(trixel_brick * brick);
void trixel_update_brick_textures(trixel_brick * brick);

void trixel_draw_from_brick(trixel_brick * brick);
void trixel_draw_brick(trixel_brick * brick);
void trixel_finish_draw(trixel_state t);

char * trixel_resource_filename(trixel_state t, char const * filename);

char * contents_from_filename(char const * filename, size_t * out_length);

trixel_brick * trixel_read_brick_from_filename(char const * filename, char * * out_error_message);

void trixel_light_param(trixel_state t, GLuint light, int param, GLfloat * param_value);

// These only free the memory used by Trixel structures, without destroying OpenGL objects
// Use in environments where the GL contexts are managed independent of your code (e.g. GC-enabled Cocoa)
void trixel_only_free_brick(trixel_brick * brick);
void trixel_state_free(trixel_state t);

#endif /* _TRIXEL_H_ */
