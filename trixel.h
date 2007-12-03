#ifndef _TRIXEL_H_
#define _TRIXEL_H_

#include <GL/glew.h>
#include <stdbool.h>

// Shader flags:
#define TRIXEL_SAVE_COORDINATES "TRIXEL_SAVE_COORDINATES"
#define TRIXEL_SURFACE_ONLY "TRIXEL_SURFACE_ONLY"
#define TRIXEL_LIGHTING "TRIXEL_LIGHTING"
#define TRIXEL_SMOOTH_SHADING "TRIXEL_SMOOTH_SHADING"

#define TRIXEL_LIGHT_PARAM_POSITION "position"
#define TRIXEL_LIGHT_PARAM_AMBIENT  "ambient"
#define TRIXEL_LIGHT_PARAM_DIFFUSE  "diffuse"

struct point3 {
    float x, y, z;
};

#define POINT3(x, y, z) ((struct point3){ (x), (y), (z) })

static inline struct point3 add_point3(struct point3 a, struct point3 b) 
    { return (struct point3){ a.x + b.x, a.y + b.y, a.z + b.z }; }
static inline struct point3 sub_point3(struct point3 a, struct point3 b) 
    { return (struct point3){ a.x - b.x, a.y - b.y, a.z - b.z }; }
static inline bool in_point3(struct point3 bound, struct point3 p) 
    { return p.x >= 0 && p.y >= 0 && p.z >= 0 && p.x < bound.x && p.y < bound.y && p.z < bound.z; }

typedef struct tag_trixel_brick {
    struct point3 dimensions, dimensions_inv;
    unsigned char * palette_data;
    unsigned char * voxmap_data;
    GLuint palette_texture, voxmap_texture, vertex_buffer;
} trixel_brick;

typedef void * trixel_state;

static inline unsigned char * trixel_brick_voxel(trixel_brick * b, int x, int y, int z)
    { return &b->voxmap_data[x + y * (int)b->dimensions.x + z * (int)b->dimensions.x * (int)b->dimensions.y]; }
static inline unsigned char * trixel_brick_palette_color(trixel_brick * b, int color)
    { return &b->palette_data[color * 4]; }
static inline size_t trixel_brick_voxmap_size(trixel_brick const * b)
    { return (size_t)b->dimensions.x * (size_t)b->dimensions.y * (size_t)b->dimensions.z; }

trixel_state trixel_init_opengl(char const * resource_path, int viewport_width, int viewport_height, char const * shader_flags[], char * * out_error_message);
void trixel_reshape(trixel_state t, int viewport_width, int viewport_height);
int trixel_update_shaders(trixel_state t, char const * shader_flags[], char * * out_error_message);

void trixel_finish(trixel_state t);

trixel_brick * trixel_read_brick(void const * data, size_t data_length, bool prepare, char * * out_error_message);
trixel_brick * trixel_make_solid_brick(int w, int h, int d, bool prepare, char * * out_error_message);
trixel_brick * trixel_make_empty_brick(int w, int h, int d, bool prepare, char * * out_error_message);
trixel_brick * trixel_copy_brick(trixel_brick const *brick, bool prepare, char * * out_error_message);
void trixel_free_brick(trixel_brick * brick);
void * trixel_write_brick(trixel_brick * brick, size_t * out_data_length);

// NB: these don't call trixel_update_brick_textures for you!
unsigned trixel_optimize_brick_palette(trixel_brick * brick);
unsigned char * trixel_insert_brick_palette_color(trixel_brick * brick, int color);
void trixel_remove_brick_palette_color(trixel_brick * brick, int color);

void trixel_prepare_brick(trixel_brick * brick);
void trixel_unprepare_brick(trixel_brick * brick);
bool trixel_is_brick_prepared(trixel_brick * brick);
void trixel_update_brick_textures(trixel_brick * brick);

void trixel_draw_from_brick(trixel_state t, trixel_brick * brick);
void trixel_draw_brick(trixel_state t, trixel_brick * brick);

char * trixel_resource_filename(trixel_state t, char const * filename);

char * contents_from_filename(char const * filename, size_t * out_length);

trixel_brick * trixel_read_brick_from_filename(char const * filename, bool prepare, char * * out_error_message);

void trixel_light_param(trixel_state t, GLuint light, char const * param_name, GLfloat * param_value);

// These only free the memory used by Trixel structures, without destroying OpenGL objects
// Use in environments where the GL contexts are managed independent of your code (e.g. GC-enabled Cocoa)
void trixel_only_free_brick(trixel_brick * brick);
void trixel_only_free(trixel_state t);

#endif /* _TRIXEL_H_ */
