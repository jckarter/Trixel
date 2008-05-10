// Tesselated renderer with ARB_fragment_program/ARB_vertex_program

#include "trixel.h"
#include "trixel_internal.h"
#include <GL/glew.h>

struct trixel_render_path arbfvp_render_path = {
    arbfvp_can_use_render_path,
    arbfvp_update_shaders,
    arbfvp_delete_shaders,
    arbfvp_set_light_param,
    arbfvp_make_vertex_buffer_for_brick,
    arbfvp_draw_from_brick
};
