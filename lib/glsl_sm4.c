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

static const int NUM_FRAGMENT_SHADERS = 5;

struct glsl_sm4_shaders {
    GLuint voxel_program, voxel_vertex_shader, voxel_fragment_shaders[NUM_FRAGMENT_SHADERS];
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

static GLuint
_glsl_shader_from_string(GLenum kind, int shader_flags, char const * source, char * * out_error_message)
{
    GLuint shader = glCreateShader(kind);
    glShaderSource(shader, 1, &shader_flag_sources, NULL);
    glCompileShader(shader);

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
_glsl_program_from_shaders(GLuint vertex, GLuint fragments[NUM_FRAGMENT_SHADERS], char * * out_error_message)
{
    GLuint program = glCreateProgram();
    glAttachShader(program, vertex);
    for(int i = 0; i < NUM_FRAGMENT_SHADERS; ++i)
        glAttachShader(program, fragments[i]);
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
    return GLEW_VERSION_2_0;
}

static void
glsl_sm4_delete_shaders(trixel_state t)
{
    struct glsl_sm4_shaders * shaders = GLSL_SM4(t);
    if(shaders) {
        glDetachShader(shaders->voxel_program, shaders->voxel_vertex_shader);
        glDetachShader(shaders->voxel_program, shaders->voxel_fragment_shader);

        glDeleteShader(shaders->voxel_fragment_shader);
        glDeleteShader(shaders->voxel_vertex_shader);
        glDeleteProgram(shaders->voxel_program);
    
        free(shaders);
    }
}

static void
glsl_sm4_make_vertex_buffer_for_brick(trixel_state t, trixel_brick * brick)
{
    GLshort width2  = (GLshort)brick->v.dimensions.x / 2,
            height2 = (GLshort)brick->v.dimensions.y / 2,
            depth2  = (GLshort)brick->v.dimensions.z / 2;
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

    brick->num_vertices = 24;
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
    if(STATE(t)->shader_flags & TRIXEL_SMOOTH_SHADING) {
        glUniform3fv(shaders->voxel_uniforms.normal_scale, 1, (GLfloat *)&brick->normal_scale);
        glUniform3fv(shaders->voxel_uniforms.normal_translate, 1, (GLfloat *)&brick->normal_translate);
        glUniform1i(shaders->voxel_uniforms.normals, 2);
    }
}

static void
glsl_sm4_finish_draw(trixel_state t)
{
    glUseProgram(0);
}

static void *
glsl_sm4_make_shaders(trixel_state t, int shader_flags, char * * out_error_message)
{
    struct glsl_sm4_shaders * shaders = malloc(sizeof(struct glsl_sm4_shaders));
    
    char *vertex_source_path = trixel_resource_filename(t, "shaders/glsl_sm4/voxel.vertex.glsl");
    char *vertex_source   = contents_from_filename(vertex_source_path, NULL);
    char *fragment_source = contents_from_filename(fragment_source_path, NULL);
    if(!vertex_source || !fragment_source) {
        *out_error_message = strdup("Failed to load shader source for the voxmap renderer.");
        goto error;
    }

    static char const * fragment_source_names[NUM_FRAGMENT_SHADERS] = {
        "voxel",
        "save-coordinates",
        "surface-only",
        "lighting",
        "smooth-shading"
    };

    char *fragment_source_path = trixel_resource_filename(t, "shaders/glsl_sm4/voxel.fragment.glsl");

    GLuint voxel_vertex_shader = _glsl_shader_from_string(GL_VERTEX_SHADER, shader_flags, vertex_source, out_error_message);
    if(!voxel_vertex_shader)
        goto error;
    GLuint voxel_fragment_shader = _glsl_shader_from_string(GL_FRAGMENT_SHADER, shader_flags, fragment_source, out_error_message);
    if(!voxel_fragment_shader)
        goto error_after_vertex_shader;
    GLuint voxel_program = _glsl_program_from_shaders(voxel_vertex_shader, voxel_fragment_shader, out_error_message);
    if(!voxel_program)
        goto error_after_fragment_shader;

    shaders->voxel_vertex_shader = voxel_vertex_shader;
    shaders->voxel_fragment_shader = voxel_fragment_shader;
    shaders->voxel_program = voxel_program;
    shaders->voxel_uniforms.voxmap = glGetUniformLocation(shaders->voxel_program, "voxmap");
    shaders->voxel_uniforms.palette = glGetUniformLocation(shaders->voxel_program, "palette");
    shaders->voxel_uniforms.voxmap_size = glGetUniformLocation(shaders->voxel_program, "voxmap_size");
    shaders->voxel_uniforms.voxmap_size_inv = glGetUniformLocation(shaders->voxel_program, "voxmap_size_inv");

    if(shader_flags & TRIXEL_SMOOTH_SHADING) {
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
    if(vertex_source) free(vertex_source);
    if(fragment_source) free(fragment_source);
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
glsl_sm4_set_light_param(trixel_state t, GLuint light, int param, GLfloat * value)
{
    static char const * const param_names[] = {
        "position",
        "ambient",
        "diffuse"
    };
    GLint uniform = _light_param_location(t, light, param_names[param]);
    glUseProgram(GLSL_SM4(t)->voxel_program);
    glUniform4fv(uniform, 1, value);
    glUseProgram(0);
}

const struct trixel_render_path glsl_sm4_render_path = {
    "GLSL Shader Model 4",
    glsl_sm4_can_use_render_path,
    glsl_sm4_make_shaders,
    glsl_sm4_delete_shaders,
    glsl_sm4_set_light_param,
    glsl_sm4_make_vertex_buffer_for_brick,
    glsl_sm4_draw_from_brick,
    glsl_sm4_finish_draw
};

