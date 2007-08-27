#ifndef _TRIXEL_H_
#define _TRIXEL_H_

#include <GL/glew.h>

typedef struct tag_trixel_brick {
    float dimensions[3], dimensions_inv[3];
    char * palette_data;
    char * voxmap_data;
    GLuint palette_texture, voxmap_texture, vertex_buffer;
} trixel_brick;

int trixel_init_opengl(char const * resource_path, int viewport_width, int viewport_height, char * * out_error_message);
void trixel_reshape(int viewport_width, int viewport_height);
int trixel_update_shaders(char * * out_error_message);

void trixel_finish(void);

trixel_brick * trixel_read_brick(void * data, size_t data_length, char * * out_error_message);
void trixel_free_brick(trixel_brick * brick);
void trixel_brick_update_textures(trixel_brick * brick);
void * trixel_write_brick(trixel_brick * brick, size_t * out_data_length);

void trixel_draw_from_brick(trixel_brick * brick);
void trixel_draw_brick(trixel_brick * brick);

char * trixel_resource_filename(char const * filename);

char * contents_from_filename(char const * filename, size_t * out_length);

trixel_brick * trixel_read_brick_from_filename(char const * filename, char * * out_error_message);

#endif /* _TRIXEL_H_ */
