#ifndef _TRIXEL_H_
#define _TRIXEL_H_

#include <GL/glew.h>
#include <stdbool.h>

// Shader flags:
#define TRIXEL_SAVE_COORDINATES "TRIXEL_SAVE_COORDINATES"
#define TRIXEL_GRID "TRIXEL_GRID"

struct point3 {
    float x, y, z;
};

typedef struct tag_trixel_brick {
    float dimensions[3], dimensions_inv[3];
    unsigned char * palette_data;
    unsigned char * voxmap_data;
    GLuint palette_texture, voxmap_texture, vertex_buffer;
} trixel_brick;

typedef void * trixel_state;

static inline unsigned char * trixel_brick_voxel(trixel_brick * b, int x, int y, int z)
    { return &b->voxmap_data[x + y * (int)b->dimensions[0] + z * (int)b->dimensions[0] * (int)b->dimensions[1]]; }
static inline unsigned char * trixel_brick_palette_color(trixel_brick * b, int color)
    { return &b->palette_data[color * 4]; }
static inline size_t trixel_brick_voxmap_size(trixel_brick * b)
    { return (size_t)b->dimensions[0] * (size_t)b->dimensions[1] * (size_t)b->dimensions[2]; }

trixel_state trixel_init_opengl(char const * resource_path, int viewport_width, int viewport_height, char const * shader_flags[], char * * out_error_message);
void trixel_reshape(trixel_state t, int viewport_width, int viewport_height);
int trixel_update_shaders(trixel_state t, char const * shader_flags[], char * * out_error_message);

void trixel_finish(trixel_state t);

trixel_brick * trixel_read_brick(void * data, size_t data_length, bool prepare, char * * out_error_message);
void trixel_free_brick(trixel_brick * brick);
void * trixel_write_brick(trixel_brick * brick, size_t * out_data_length);

void trixel_prepare_brick(trixel_brick * brick);
void trixel_unprepare_brick(trixel_brick * brick);
bool trixel_is_brick_prepared(trixel_brick * brick);
void trixel_update_brick_textures(trixel_brick * brick);

void trixel_draw_from_brick(trixel_state t, trixel_brick * brick);
void trixel_draw_brick(trixel_state t, trixel_brick * brick);

char * trixel_resource_filename(trixel_state t, char const * filename);

char * contents_from_filename(char const * filename, size_t * out_length);

trixel_brick * trixel_read_brick_from_filename(char const * filename, bool prepare, char * * out_error_message);

#endif /* _TRIXEL_H_ */
