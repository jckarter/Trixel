#ifndef _TRIXEL_INTERNAL_H_
#define _TRIXEL_INTERNAL_H_

struct trixel_internal_state {
    struct trixel_render_path const * render_path;
    char * resource_path;
    void * shaders;
};

static inline struct trixel_internal_state * STATE(trixel_state t) { return (struct trixel_internal_state *)t; }

struct trixel_render_path {
    bool   (*can_be_used)(trixel_state t);
    void * (*make_shaders)(trixel_state t, int shader_flags, char * * out_error_message);
    void   (*delete_shaders)(trixel_state t);
    void   (*set_light_param)(trixel_state t, GLuint light, char const * param_name, GLfloat * value);
    void   (*make_vertex_buffer_for_brick)(trixel_state t, trixel_brick * brick);
    void   (*draw_from_brick)(trixel_state t, trixel_brick * brick);
};

extern const struct trixel_render_path glsl_sm4_render_path, arbfvp_render_path;
//extern struct trixel_render_path arbfvp;

#endif
