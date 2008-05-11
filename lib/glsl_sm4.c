// GLSL raycasting shader implementation (requires "Shader Model 4" video card for hardware acceleration)

#include "trixel.h"
#include "trixel_internal.h"
#include <GL/glew.h>
#include <math.h>
#include <string.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>

struct glsl_sm4_shaders {
    int shader_flags;
    GLuint voxel_program, voxel_vertex_shader, voxel_fragment_shader;
    struct voxel_program_uniforms {
        GLint voxmap, palette, normals, normal_translate, normal_scale, voxmap_size, voxmap_size_inv;
    } voxel_uniforms;
};

static inline struct glsl_sm4_shaders *
GLSL_SM4(trixel_state t)
{
    return (struct glsl_sm4_shaders *)(STATE(t)->shaders);
}

static int
_bit_count(int x)
{
    int c = 0;
    for(int b = 1; b; b <<= 1)
        if(x & b) ++c;
    return c;

}

static char * *
_make_shader_flag_sources(int flags, char const * source, size_t *out_num_sources)
{
    if(!flags) {
        char * * flag_sources = malloc(sizeof(char *));
        *flag_sources = strdup(source);
        *out_num_sources = 1;
        return flag_sources;
    }

    static char const * flag_names[] = {
        "TRIXEL_SAVE_COORDINATES",
        "TRIXEL_SURFACE_ONLY",
        "TRIXEL_LIGHTING",
        "TRIXEL_SMOOTH_SHADING",
        NULL
    };

    size_t num_flags = _bit_count(flags);

    char * * flag_sources = malloc((num_flags + 1) * sizeof(char*));

    size_t flag_i, bit_i;
    int b;
    for(flag_i = 0, bit_i = 0, b = 1;
        flag_names[bit_i];
        ++bit_i, b <<= 1)
        if(flags & b)
            asprintf(&flag_sources[flag_i++], "#define %s 1\n", flags[bit_i]);

    flag_sources[num_flags] = strdup(source);
    *out_num_sources = num_flags + 1;
    return flag_sources;
}

static void
_free_shader_flag_sources(char * sources[], size_t num_sources)
{
    for(size_t i = 0; i < num_sources; ++i)
        free(sources[i]);
    free(sources);
}

static GLuint
_glsl_shader_from_string(GLenum kind, int shader_flags, char const * source, char * * out_error_message)
{
    size_t num_sources;
    char * * shader_flag_sources = _make_shader_flag_sources(shader_flags, source, &num_sources);
    GLuint shader = glCreateShader(kind);
    glShaderSource(shader, num_sources, (const GLchar**)shader_flag_sources, NULL);
    glCompileShader(shader);

    _free_shader_flag_sources(shader_flag_sources, num_sources);

    GLint status;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    if(!status) {
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &status);
        *out_error_message = malloc(status);
        glGetShaderInfoLog(shader, status, &status, *out_error_message);
        goto error;
    }
    return shader;

error:
    glDeleteShader(shader);
    return 0;
}

static GLuint
_glsl_program_from_shaders(GLuint vertex, GLuint fragment, char * * out_error_message)
{
    GLuint program = glCreateProgram();
    glAttachShader(program, vertex);
    glAttachShader(program, fragment);
    glLinkProgram(program);

    GLint status;
    glGetProgramiv(program, GL_LINK_STATUS, &status);
    if(!status) {
        glGetProgramiv(program, GL_INFO_LOG_LENGTH, &status);
        *out_error_message = malloc(status);
        glGetProgramInfoLog(program, status, &status, *out_error_message);
        goto error;
    }
    return program;

error:
    glDeleteShader(program);
    return 0;
}

static bool
glsl_sm4_can_use_render_path(trixel_state t)
{
    return GLEW_VERSION_2_0 && GLEW_EXT_framebuffer_object && GLEW_ARB_texture_float;
}

static void
glsl_sm4_delete_shaders(trixel_state t)
{
    if(GLSL_SM4(t)) {
        glDetachShader(GLSL_SM4(t)->voxel_program, GLSL_SM4(t)->voxel_vertex_shader);
        glDetachShader(GLSL_SM4(t)->voxel_program, GLSL_SM4(t)->voxel_fragment_shader);

        glDeleteShader(GLSL_SM4(t)->voxel_fragment_shader);
        glDeleteShader(GLSL_SM4(t)->voxel_vertex_shader);
        glDeleteProgram(GLSL_SM4(t)->voxel_program);
    
        GLSL_SM4(t)->voxel_fragment_shader = 0;
        GLSL_SM4(t)->voxel_vertex_shader = 0;
        GLSL_SM4(t)->voxel_program = 0;
        free(GLSL_SM4(t));
    }
}

static void
glsl_sm4_make_vertex_buffer_for_brick(trixel_state t, trixel_brick * brick)
{
    GLshort width2  = (GLshort)brick->dimensions.x / 2,
            height2 = (GLshort)brick->dimensions.y / 2,
            depth2  = (GLshort)brick->dimensions.z / 2;
    struct {
        GLshort vertices[6*4*3];
        GLbyte  normals [6*4*3];
    } buffer = {
        {
            -width2, -height2, -depth2,
            -width2,  height2, -depth2,
             width2,  height2, -depth2,
             width2, -height2, -depth2,
         
             width2, -height2, -depth2,
             width2,  height2, -depth2,
             width2,  height2,  depth2,
             width2, -height2,  depth2,
         
             width2, -height2,  depth2,
             width2,  height2,  depth2,
            -width2,  height2,  depth2,
            -width2, -height2,  depth2,
        
            -width2, -height2,  depth2,
            -width2,  height2,  depth2,
            -width2,  height2, -depth2,
            -width2, -height2, -depth2,
        
             width2,  height2,  depth2,
             width2,  height2, -depth2,
            -width2,  height2, -depth2,
            -width2,  height2,  depth2,

            -width2, -height2,  depth2,
            -width2, -height2, -depth2,
             width2, -height2, -depth2,
             width2, -height2,  depth2
        },
        {
             0,  0, -128,
             0,  0, -128,
             0,  0, -128,
             0,  0, -128,

             127,  0,  0,
             127,  0,  0,
             127,  0,  0,
             127,  0,  0,

             0,  0,  127,
             0,  0,  127,
             0,  0,  127,
             0,  0,  127,

            -128,  0,  0,
            -128,  0,  0,
            -128,  0,  0,
            -128,  0,  0,

             0,  127,  0,
             0,  127,  0,
             0,  127,  0,
             0,  127,  0,

             0, -128,  0,
             0, -128,  0,
             0, -128,  0,
             0, -128,  0
        }
    };

    glGenBuffers(1, &brick->vertex_buffer);
    glBindBuffer(GL_ARRAY_BUFFER, brick->vertex_buffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(buffer), &buffer, GL_STATIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
}

static void
glsl_sm4_draw_from_brick(trixel_state t, trixel_brick * brick)
{
    struct glsl_sm4_shaders * shaders = GLSL_SM4(t);
    
    glUseProgram(shaders->voxel_program);
    glUniform3fv(shaders->voxel_uniforms.voxmap_size,     1, (GLfloat *)&brick->dimensions);
    glUniform3fv(shaders->voxel_uniforms.voxmap_size_inv, 1, (GLfloat *)&brick->dimensions_inv);
    glUniform1i(shaders->voxel_uniforms.voxmap,  0);
    glUniform1i(shaders->voxel_uniforms.palette, 1);
    if(shaders->has_smooth_shading) {
        glUniform3fv(shaders->voxel_uniforms.normal_scale, 1, (GLfloat *)&brick->normal_scale);
        glUniform3fv(shaders->voxel_uniforms.normal_translate, 1, (GLfloat *)&brick->normal_translate);
        glUniform1i(shaders->voxel_uniforms.normals, 2);
    }
}

static void *
glsl_sm4_make_shaders(trixel_state t, int shader_flags, char * * out_error_message)
{
    struct glsl_sm4_shaders * shaders = malloc(sizeof(struct glsl_sm4_shaders));
    
    char *vertex_source_path = trixel_resource_filename(t, "shaders/glsl_sm4/voxel.vertex.glsl");
    char *fragment_source_path = trixel_resource_filename(t, "shaders/glsl_sm4/voxel.fragment.glsl");
    char *vertex_source   = contents_from_filename(vertex_source_path, NULL);
    char *fragment_source = contents_from_filename(fragment_source_path, NULL);
    if(!vertex_source || !fragment_source) {
        *out_error_message = strdup("Failed to load shader source for the voxmap renderer.");
        goto error;
    }

    GLuint voxel_vertex_shader = _glsl_shader_from_string(GL_VERTEX_SHADER, shader_flags, vertex_source, out_error_message);
    if(!voxel_vertex_shader)
        goto error;
    GLuint voxel_fragment_shader = _glsl_shader_from_string(GL_FRAGMENT_SHADER, shader_flags, fragment_source, out_error_message);
    if(!voxel_fragment_shader)
        goto error_after_vertex_shader;
    GLuint voxel_program = _glsl_program_from_shaders(voxel_vertex_shader, voxel_fragment_shader, out_error_message);
    if(!voxel_program)
        goto error_after_fragment_shader;

    shaders->has_smooth_shading = _has_flag(shader_flags, TRIXEL_SMOOTH_SHADING);

    shaders->voxel_vertex_shader = voxel_vertex_shader;
    shaders->voxel_fragment_shader = voxel_fragment_shader;
    shaders->voxel_program = voxel_program;
    shaders->voxel_uniforms.voxmap = glGetUniformLocation(shaders->voxel_program, "voxmap");
    shaders->voxel_uniforms.palette = glGetUniformLocation(shaders->voxel_program, "palette");
    shaders->voxel_uniforms.voxmap_size = glGetUniformLocation(shaders->voxel_program, "voxmap_size");
    shaders->voxel_uniforms.voxmap_size_inv = glGetUniformLocation(shaders->voxel_program, "voxmap_size_inv");

    if(shaders->has_smooth_shading) {
        shaders->voxel_uniforms.normals = glGetUniformLocation(shaders->voxel_program, "normals");
        shaders->voxel_uniforms.normal_scale = glGetUniformLocation(shaders->voxel_program, "normal_scale");
        shaders->voxel_uniforms.normal_translate = glGetUniformLocation(shaders->voxel_program, "normal_translate");
    }

    free(vertex_source);
    free(fragment_source);
    free(vertex_source_path);
    free(fragment_source_path);
    return shaders;

error_after_fragment_shader:
    glDeleteShader(voxel_fragment_shader);
error_after_vertex_shader:
    glDeleteShader(voxel_vertex_shader);
error:
    free(vertex_source);
    free(fragment_source);
    free(vertex_source_path);
    free(fragment_source_path);
    free(shaders);
    return NULL;
}

static GLint
_light_param_location(trixel_state t, GLuint light, char const * param_name)
{
    size_t buflen = 9 + 11 + strlen(param_name) + 1; // length of "lights[].", -MAX_INT, param_name, and '\0'
    char name[buflen];
    snprintf(name, buflen, "lights[%u].%s", light, param_name);
    GLint r = glGetUniformLocation(GLSL_SM4(t)->voxel_program, name);
    return r;
}

static void
glsl_sm4_set_light_param(trixel_state t, GLuint light, char const * param_name, GLfloat * value)
{
    GLint uniform = _light_param_location(t, light, param_name);
    glUseProgram(GLSL_SM4(t)->voxel_program);
    glUniform4fv(uniform, 1, value);
}

const struct trixel_render_path glsl_sm4_render_path = {
    glsl_sm4_can_use_render_path,
    glsl_sm4_make_shaders,
    glsl_sm4_delete_shaders,
    glsl_sm4_set_light_param,
    glsl_sm4_make_vertex_buffer_for_brick,
    glsl_sm4_draw_from_brick
};

