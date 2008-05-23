// GLSL raycasting shader implementation (requires "Shader Model 4" video card for hardware acceleration)

#include "trixel.h"
#include "trixel_internal.h"
#include "voxmap.h"
#include <GL/glew.h>
#include <math.h>
#include <string.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>

#define NUM_FRAGMENT_SHADERS 6

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
_glsl_shader_from_string(GLenum kind, char const * source, char * * out_error_message)
{
    GLuint shader = glCreateShader(kind);
    glShaderSource(shader, 1, &source, NULL);
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
        glDeleteShader(shaders->voxel_vertex_shader);
        for(int i = 0; i < NUM_FRAGMENT_SHADERS; ++i) {
            glDetachShader(shaders->voxel_program, shaders->voxel_fragment_shaders[i]);
            glDeleteShader(shaders->voxel_fragment_shaders[i]);
        }
        glDeleteProgram(shaders->voxel_program);
    
        free(shaders);
    }
}

static void
glsl_sm4_make_vertex_buffer_for_brick(trixel_state t, trixel_brick * brick)
{
    struct point3 dims2 = mul_point3(brick->dimensions, POINT3(0.5, 0.5, 0.5)), min, max;
    struct int3 imin, imax;
    
    voxmap_spans(&brick->v, &imin, &imax);
    min = sub_point3(POINT3_OF_INT3(imin), dims2);
    max = sub_point3(POINT3_OF_INT3(imax), dims2);

    struct {
        GLfloat vertices[6*4*3];
        GLfloat normals [6*4*3];
    } buffer = {
        {
            min.x, min.y, min.z,
            min.x, max.y, min.z,
            max.x, max.y, min.z,
            max.x, min.y, min.z,
         
            max.x, min.y, min.z,
            max.x, max.y, min.z,
            max.x, max.y, max.z,
            max.x, min.y, max.z,
         
            max.x, min.y, max.z,
            max.x, max.y, max.z,
            min.x, max.y, max.z,
            min.x, min.y, max.z,
        
            min.x, min.y, max.z,
            min.x, max.y, max.z,
            min.x, max.y, min.z,
            min.x, min.y, min.z,
        
            max.x, max.y, max.z,
            max.x, max.y, min.z,
            min.x, max.y, min.z,
            min.x, max.y, max.z,

            min.x, min.y, max.z,
            min.x, min.y, min.z,
            max.x, min.y, min.z,
            max.x, min.y, max.z
        },
        {
             0,  0, -1,
             0,  0, -1,
             0,  0, -1,
             0,  0, -1,

             1,  0,  0,
             1,  0,  0,
             1,  0,  0,
             1,  0,  0,

             0,  0,  1,
             0,  0,  1,
             0,  0,  1,
             0,  0,  1,

            -1,  0,  0,
            -1,  0,  0,
            -1,  0,  0,
            -1,  0,  0,

             0,  1,  0,
             0,  1,  0,
             0,  1,  0,
             0,  1,  0,

             0, -1,  0,
             0, -1,  0,
             0, -1,  0,
             0, -1,  0
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
    GLuint voxel_vertex_shader;
    
    char *vertex_source_path = trixel_resource_filename(t, "shaders/glsl_sm4/voxel.vertex.glsl");
    char *vertex_source   = contents_from_filename(vertex_source_path, NULL);
    free(vertex_source_path);
    if(!vertex_source) {
        *out_error_message = strdup("Failed to load vertex shader source.");
        goto error;
    }
    voxel_vertex_shader = _glsl_shader_from_string(GL_VERTEX_SHADER, vertex_source, out_error_message);
    free(vertex_source);
    if(!voxel_vertex_shader)
        goto error;

    static char const * fragment_source_names[NUM_FRAGMENT_SHADERS] = {
        NULL,
        "save-coordinates",
        "surface-only",
        "lighting",
        "smooth-shading",
        "exact-depth"
    };
    GLuint voxel_fragment_shader[NUM_FRAGMENT_SHADERS];
    
    memset(voxel_fragment_shader, 0, sizeof(voxel_fragment_shader));
    
    char *fragment_source0_path = trixel_resource_filename(t, "shaders/glsl_sm4/voxel.fragment.glsl");
    char *fragment_source0 = contents_from_filename(fragment_source0_path, NULL);
    free(fragment_source0_path);
    if(!fragment_source0) {
        *out_error_message = strdup("Failed to load fragment shader source.");
        goto error_after_vertex_shader;
    }
    voxel_fragment_shader[0] = _glsl_shader_from_string(GL_FRAGMENT_SHADER, fragment_source0, out_error_message);
    free(fragment_source0);
    if(!voxel_fragment_shader[0])
        goto error_after_vertex_shader;

    for(int i = 1, flags_mask = 1; i < NUM_FRAGMENT_SHADERS; ++i, flags_mask <<= 1) {
        char *fragment_source_filename;
        asprintf(&fragment_source_filename, "shaders/glsl_sm4/%s%s.fragment.glsl",
            (shader_flags & flags_mask ? "" : "no-"),
            fragment_source_names[i]
        );
        fprintf(stderr, "%s\n", fragment_source_filename);
        char *fragment_source_path = trixel_resource_filename(t, fragment_source_filename);
        free(fragment_source_filename);
        char *fragment_source = contents_from_filename(fragment_source_path, NULL);
        free(fragment_source_path);
        if(!fragment_source) {
            *out_error_message = strdup("Failed to load fragment shader source.");
            goto error_after_fragment_shader;
        }
        voxel_fragment_shader[i] = _glsl_shader_from_string(GL_FRAGMENT_SHADER, fragment_source, out_error_message);
        free(fragment_source);
        if(!voxel_fragment_shader[i])
            goto error_after_fragment_shader;
    }
    
    GLuint voxel_program = _glsl_program_from_shaders(voxel_vertex_shader, voxel_fragment_shader, out_error_message);
    if(!voxel_program)
        goto error_after_fragment_shader;

    struct glsl_sm4_shaders * shaders = malloc(sizeof(struct glsl_sm4_shaders));

    shaders->voxel_vertex_shader = voxel_vertex_shader;
    memcpy(shaders->voxel_fragment_shaders, voxel_fragment_shader, sizeof(voxel_fragment_shader));
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

    return shaders;

error_after_fragment_shader:
    for(int i = 0; i < NUM_FRAGMENT_SHADERS; ++i)
        if(voxel_fragment_shader[i])
            glDeleteShader(voxel_fragment_shader[i]);
error_after_vertex_shader:
    glDeleteShader(voxel_vertex_shader);
error:
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

