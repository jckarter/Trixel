#include "trixel.h"

#include <GL/glew.h>
#include <math.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>

#define NEAR_PLANE 4.0
#define FAR_PLANE  1024.0
#define FOV        2.41421

#define BRICK_MAGIC "Brik"

static struct state {
    char * resource_path;
    GLhandleARB voxel_program, voxel_vertex_shader, voxel_fragment_shader;
    GLuint cube_element_buffer;
    struct voxel_program_uniforms {
        GLint voxmap, palette, voxmap_size, voxmap_size_inv;
    } voxel_uniforms;
} g_state;

static unsigned char g_cube_elements[] = {
    1, 2, 3, 0,
    2, 1, 5, 6,
    6, 5, 4, 7,
    7, 4, 0, 3,
    2, 6, 7, 3,
    5, 1, 0, 4
};

static int
_gl_print_matrix(GLenum what)
{
    GLdouble matrix[16];
    glGetDoublev(what, matrix);
    printf("[%11.5f %11.5f %11.5f %11.5f]\n"
           "[%11.5f %11.5f %11.5f %11.5f]\n"
           "[%11.5f %11.5f %11.5f %11.5f]\n"
           "[%11.5f %11.5f %11.5f %11.5f]\n",
           matrix[ 0], matrix[ 1], matrix[ 2], matrix[ 3],
           matrix[ 4], matrix[ 5], matrix[ 6], matrix[ 7],
           matrix[ 8], matrix[ 9], matrix[10], matrix[11],
           matrix[12], matrix[13], matrix[14], matrix[15]
    );
}

static GLhandleARB
glsl_shader_from_string(GLenum kind, char const *source, char * * out_error_message)
{
    GLhandleARB shader = glCreateShaderObjectARB(kind);
    glShaderSourceARB(shader, 1, &source, NULL);
    glCompileShaderARB(shader);

    GLint status;
    glGetObjectParameterivARB(shader, GL_OBJECT_COMPILE_STATUS_ARB, &status);
    if(!status) {
        glGetObjectParameterivARB(shader, GL_OBJECT_INFO_LOG_LENGTH_ARB, &status);
        *out_error_message = malloc(status);
        glGetInfoLogARB(shader, status, &status, *out_error_message);
        goto error;
    }
    return shader;

error:
    glDeleteObjectARB(shader);
    return 0;
}

static GLhandleARB
glsl_program_from_shaders(GLhandleARB vertex, GLhandleARB fragment, char * * out_error_message)
{
    GLhandleARB program = glCreateProgramObjectARB();
    glAttachObjectARB(program, vertex);
    glAttachObjectARB(program, fragment);
    glLinkProgramARB(program);

    GLint status;
    glGetObjectParameterivARB(program, GL_OBJECT_LINK_STATUS_ARB, &status);
    if(!status) {
        glGetObjectParameterivARB(program, GL_OBJECT_INFO_LOG_LENGTH_ARB, &status);
        *out_error_message = malloc(status);
        glGetInfoLogARB(program, status, &status, *out_error_message);
        goto error;
    }
    return program;

error:
    glDeleteObjectARB(program);
    return 0;
}

char *
trixel_resource_filename(char const * filename)
{
    char * full_filename;
    asprintf(&full_filename, "%s/%s", g_state.resource_path, filename);
    return full_filename;
}

char *
contents_from_filename(char const * filename, size_t * out_length)
{
    FILE * f = fopen(filename, "rb");
    if(!f)
        goto error;

    fseek(f, 0, SEEK_END);
    size_t size = ftell(f);
    fseek(f, 0, SEEK_SET);

    char * buf = malloc(size+1);
    if(!buf)
        goto error_after_fopen_f;
    if(fread(buf, 1, size, f) != size)
        goto error_after_malloc_buf;
    fclose(f);

    buf[size] = '\0';
    if(out_length)
        *out_length = size;
    return buf;

error_after_malloc_buf:
    free(buf);
error_after_fopen_f:
    fclose(f);
error:
    return NULL;
}

static void
unmake_voxel_program(void)
{
    glDetachObjectARB(g_state.voxel_program, g_state.voxel_vertex_shader);
    glDetachObjectARB(g_state.voxel_program, g_state.voxel_fragment_shader);

    glDeleteObjectARB(g_state.voxel_fragment_shader);
    glDeleteObjectARB(g_state.voxel_vertex_shader);
    glDeleteObjectARB(g_state.voxel_program);

    g_state.voxel_fragment_shader = 0;
    g_state.voxel_vertex_shader = 0;
    g_state.voxel_program = 0;
}

int
trixel_init_opengl(char const * resource_path, int viewport_width, int viewport_height, char * * out_error_message)
{
    memset(&g_state, 0, sizeof(g_state));

    GLenum glew_error = glewInit();
    if(glew_error != GLEW_OK) {
        *out_error_message = strdup((char*)glewGetErrorString(glew_error));
        goto error;
    }

    if(!GLEW_ARB_multitexture
        || !GLEW_ARB_shader_objects
        || !GLEW_ARB_shading_language_100
        || !GLEW_ARB_vertex_buffer_object) {
        *out_error_message = strdup("Your OpenGL implementation doesn't support GLSL shaders.");
        goto error;
    }

    glClearColor(0.2, 0.2, 0.2, 1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glEnable(GL_DEPTH_TEST);
    glEnable(GL_CULL_FACE);
    glEnableClientState(GL_VERTEX_ARRAY);

    if(glGetError() != GL_NO_ERROR) {
        *out_error_message = strdup("OpenGL had an error while setting up.");
        goto error;
    }

    trixel_reshape(viewport_width, viewport_height);

    g_state.resource_path = strdup(resource_path);

    glGenBuffersARB(1, &g_state.cube_element_buffer);
    glBindBufferARB(GL_ELEMENT_ARRAY_BUFFER_ARB, g_state.cube_element_buffer);
    glBufferDataARB(GL_ELEMENT_ARRAY_BUFFER_ARB, sizeof(g_cube_elements), g_cube_elements, GL_STATIC_DRAW_ARB);
    glBindBufferARB(GL_ELEMENT_ARRAY_BUFFER_ARB, 0);

    if(!trixel_update_shaders(out_error_message))
        goto error_after_save_resource_path;

    return 1;

error_after_save_resource_path:
    glDeleteBuffersARB(1, &g_state.cube_element_buffer);
    free(g_state.resource_path);
error:
    return 0;
}

void
trixel_reshape(int viewport_width, int viewport_height)
{
    float width = (float)viewport_width, height = (float)viewport_height;
    float fovratio = fmin(width, height),
          fovx = width/fovratio,
          fovy = height/fovratio;

    glViewport(0, 0, viewport_width, viewport_height);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glFrustum(
        -NEAR_PLANE / FOV * fovx, NEAR_PLANE / FOV * fovx,
        -NEAR_PLANE / FOV * fovy, NEAR_PLANE / FOV * fovy,
        NEAR_PLANE, FAR_PLANE
    );
}

int
trixel_update_shaders(char * * out_error_message)
{
    char *vertex_source_path = trixel_resource_filename("voxel.vertex.glsl");
    char *fragment_source_path = trixel_resource_filename("voxel.fragment.glsl");
    char *vertex_source   = contents_from_filename(vertex_source_path, NULL);
    char *fragment_source = contents_from_filename(fragment_source_path, NULL);
    if(!vertex_source || !fragment_source) {
        *out_error_message = strdup("Failed to load shader source for the voxmap renderer.");
    }

    GLhandleARB voxel_vertex_shader = glsl_shader_from_string(GL_VERTEX_SHADER_ARB, vertex_source, out_error_message);
    if(!voxel_vertex_shader)
        goto error;
    GLhandleARB voxel_fragment_shader = glsl_shader_from_string(GL_FRAGMENT_SHADER_ARB, fragment_source, out_error_message);
    if(!voxel_fragment_shader)
        goto error_after_vertex_shader;
    GLhandleARB voxel_program = glsl_program_from_shaders(voxel_vertex_shader, voxel_fragment_shader, out_error_message);
    if(!voxel_program)
        goto error_after_fragment_shader;

    if(g_state.voxel_program)
        unmake_voxel_program();
    g_state.voxel_vertex_shader = voxel_vertex_shader;
    g_state.voxel_fragment_shader = voxel_fragment_shader;
    g_state.voxel_program = voxel_program;
    g_state.voxel_uniforms.voxmap = glGetUniformLocationARB(g_state.voxel_program, "voxmap");
    g_state.voxel_uniforms.palette = glGetUniformLocationARB(g_state.voxel_program, "palette");
    g_state.voxel_uniforms.voxmap_size = glGetUniformLocationARB(g_state.voxel_program, "voxmap_size");
    g_state.voxel_uniforms.voxmap_size_inv = glGetUniformLocationARB(g_state.voxel_program, "voxmap_size_inv");

    free(vertex_source);
    free(fragment_source);
    free(vertex_source_path);
    free(fragment_source_path);
    return 1;

error_after_fragment_shader:
    glDeleteObjectARB(g_state.voxel_fragment_shader);
error_after_vertex_shader:
    glDeleteObjectARB(g_state.voxel_vertex_shader);
error:
    free(vertex_source);
    free(fragment_source);
    free(vertex_source_path);
    free(fragment_source_path);
    return 0;
}

void
trixel_finish(void)
{
    unmake_voxel_program();
    glDeleteBuffersARB(1, &g_state.cube_element_buffer);
    free(g_state.resource_path);
}

trixel_brick *
trixel_read_brick(void * data, size_t data_length, char * * out_error_message)
{
    uint8_t * byte_data = (uint8_t *)data;

    trixel_brick * brick = malloc(sizeof(trixel_brick));
    memset(brick, 0, sizeof(trixel_brick));

    struct brick_header {
        char magic[4];
        uint16_t colors, width, height, depth; // XXX little endian!
    } * header = (struct brick_header *)data;

    if(data_length < sizeof(struct brick_header)) {
        asprintf(out_error_message,
            "Brick data is not big enough for a header.\n"
            "(got size %u, expected header size %u)",
            data_length, sizeof(struct brick_header)
        );
        goto error;
    }
    if(strncmp(header->magic, BRICK_MAGIC, 4) != 0) {
        asprintf(out_error_message,
            "Brick data is not in brick format.\n"
            "(got magic '%4s', expected magic '%4s')",
            header->magic, BRICK_MAGIC
        );
        goto error;
    }
    if(header->colors > 255) {
        asprintf(out_error_message,
            "Brick claims to have more than 255 colors.\n"
            "(got %u colors)",
            header->colors
        );
        goto error;
    }

    size_t
        palette_offset = sizeof(struct brick_header),
        palette_length = 4 * (size_t)header->colors,
        voxmap_offset = palette_offset + palette_length,
        voxmap_length = (size_t)header->width * (size_t)header->height * (size_t)header->depth,
        total_length = sizeof(struct brick_header) + palette_length + voxmap_length;
    if(data_length < total_length) {
        asprintf(out_error_message,
            "Brick data is smaller than it claims to be.\n"
            "(got length %u, expected length %u)",
            data_length, total_length
        );
        goto error;
    }

    brick->dimensions[0] = (float)header->width;
    brick->dimensions[1] = (float)header->height;
    brick->dimensions[2] = (float)header->depth;

    brick->dimensions_inv[0] = 1.0 / brick->dimensions[0];
    brick->dimensions_inv[1] = 1.0 / brick->dimensions[1];
    brick->dimensions_inv[2] = 1.0 / brick->dimensions[2];

    brick->palette_data = malloc(256 * 4);
    memset(brick->palette_data, 0, 256 * 4);
    memcpy(brick->palette_data + 4, byte_data + palette_offset, palette_length);
    brick->voxmap_data = malloc(voxmap_length);
    memcpy(brick->voxmap_data, byte_data + voxmap_offset, voxmap_length);

    glGenTextures(1, &brick->palette_texture);
    glBindTexture(GL_TEXTURE_1D, brick->palette_texture);
    glTexParameteri(GL_TEXTURE_1D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_1D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_1D, GL_TEXTURE_WRAP_S, GL_CLAMP);

    glGenTextures(1, &brick->voxmap_texture);
    glBindTexture(GL_TEXTURE_3D, brick->voxmap_texture);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_S, GL_CLAMP);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_T, GL_CLAMP);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_R, GL_CLAMP);

    trixel_brick_update_textures(brick);

    GLshort vertices[] = {
                    0,              0,             0,
                    0, header->height,             0,
        header->width, header->height,             0,
        header->width,              0,             0,
                    0,              0, header->depth,
                    0, header->height, header->depth,
        header->width, header->height, header->depth,
        header->width,              0, header->depth
    };

    glGenBuffersARB(1, &brick->vertex_buffer);
    glBindBufferARB(GL_ARRAY_BUFFER_ARB, brick->vertex_buffer);
    glBufferDataARB(GL_ARRAY_BUFFER_ARB, sizeof(vertices), vertices, GL_STATIC_DRAW_ARB);
    glBindBufferARB(GL_ARRAY_BUFFER_ARB, 0);

    return brick;

error:
    return NULL;
}

void
trixel_free_brick(trixel_brick * brick)
{
    glDeleteBuffersARB(1, &brick->vertex_buffer);
    glDeleteTextures(1, &brick->voxmap_texture);
    glDeleteTextures(1, &brick->palette_texture);
    free(brick->voxmap_data);
    free(brick->palette_data);
    free(brick);
}

void
trixel_brick_update_textures(trixel_brick * brick)
{
    glBindTexture(GL_TEXTURE_1D, brick->palette_texture);
    glTexImage1D(GL_TEXTURE_1D, 0, GL_RGBA8, 256, 0, GL_RGBA, GL_UNSIGNED_BYTE, brick->palette_data);

    glBindTexture(GL_TEXTURE_3D, brick->voxmap_texture);
    glTexImage3D(
        GL_TEXTURE_3D, 0, GL_LUMINANCE8,
        (GLsizei)brick->dimensions[0], (GLsizei)brick->dimensions[1], (GLsizei)brick->dimensions[2],
        0, GL_LUMINANCE, GL_UNSIGNED_BYTE, brick->voxmap_data
    );
}

void *
trixel_write_brick(trixel_brick * brick, size_t * out_data_length)
{
    return NULL; // xxx rite me
}

void
trixel_draw_from_brick(trixel_brick * brick)
{
    glActiveTextureARB(GL_TEXTURE0_ARB);
    glBindTexture(GL_TEXTURE_3D, brick->voxmap_texture);
    glActiveTextureARB(GL_TEXTURE1_ARB);
    glBindTexture(GL_TEXTURE_1D, brick->palette_texture);

    glUseProgramObjectARB(g_state.voxel_program);
    glUniform3fvARB(g_state.voxel_uniforms.voxmap_size,     1, brick->dimensions);
    glUniform3fvARB(g_state.voxel_uniforms.voxmap_size_inv, 1, brick->dimensions_inv);
    glUniform1iARB(g_state.voxel_uniforms.voxmap,  0);
    glUniform1iARB(g_state.voxel_uniforms.palette, 1);
}

void
trixel_draw_brick(trixel_brick * brick)
{
    trixel_draw_from_brick(brick);

    glBindBufferARB(GL_ARRAY_BUFFER_ARB, brick->vertex_buffer);
    glBindBufferARB(GL_ELEMENT_ARRAY_BUFFER_ARB, g_state.cube_element_buffer);

    glVertexPointer(3, GL_SHORT, 0, 0);
    glDrawElements(GL_QUADS, 24, GL_UNSIGNED_BYTE, 0);

    glBindBufferARB(GL_ARRAY_BUFFER_ARB, 0);
    glBindBufferARB(GL_ELEMENT_ARRAY_BUFFER_ARB, 0);
}

trixel_brick *
trixel_read_brick_from_filename(char const * filename, char * * out_error_message)
{
    char *data;
    size_t data_length;
    data = contents_from_filename(filename, &data_length);
    if(!data) {
        asprintf(out_error_message, "Could not read from file '%s'.", filename);
        goto error;
    }

    trixel_brick *brick = trixel_read_brick(data, data_length, out_error_message);
    free(data);
    return brick;

error:
    return NULL;
}
