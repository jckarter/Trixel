#include "trixel.h"

#include <GL/glew.h>
#include <math.h>
#include <string.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>

#define NEAR_PLANE 4.0
#define FAR_PLANE  1024.0
#define FOV        2.41421

#define BRICK_MAGIC "Brik"
#define NULL_COLOR ((unsigned char *)"\0\0\0\0")

struct trixel_internal_state {
    char * resource_path;
    GLuint voxel_program, voxel_vertex_shader, voxel_fragment_shader;
    struct voxel_program_uniforms {
        GLint voxmap, palette, voxmap_size, voxmap_size_inv;
    } voxel_uniforms;
};

static inline struct trixel_internal_state * STATE(trixel_state t) { return (struct trixel_internal_state *)t; }

static void
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

static void
_gl_report_error(char const * tag)
{
    GLenum error = glGetError();
    if(error != GL_NO_ERROR) {
        fprintf(stderr, "%s: OpenGL error ", tag);
        switch(error) {
            case GL_INVALID_ENUM:
                fprintf(stderr, "GL_INVALID_ENUM");
                break;
            case GL_INVALID_VALUE:
                fprintf(stderr, "GL_INVALID_VALUE");
                break;
            case GL_INVALID_OPERATION:
                fprintf(stderr, "GL_INVALID_OPERATION");
                break;
            case GL_STACK_OVERFLOW:
                fprintf(stderr, "GL_STACK_OVERFLOW");
                break;
            case GL_STACK_UNDERFLOW:
                fprintf(stderr, "GL_STACK_UNDERFLOW");
                break;
            case GL_OUT_OF_MEMORY:
                fprintf(stderr, "GL_OUT_OF_MEMORY");
                break;
            default:
                fprintf(stderr, "code 0x%x", error);
                break;
        }
        fprintf(stderr, "\n");
    }
}

static char * *
_make_shader_flag_sources(char const * flags[], char const * source, size_t *out_num_sources)
{
    if(!flags) {
        char * * flag_sources = malloc(sizeof(char *));
        *flag_sources = strdup(source);
        *out_num_sources = 1;
        return flag_sources;
    }

    size_t num_flags = 0;
    char const * * fp = flags;
    while(*fp++)
        ++num_flags;

    char * * flag_sources = malloc((num_flags + 1) * sizeof(char*));
    for(size_t i = 0; i < num_flags; ++i)
        asprintf(&flag_sources[i], "#define %s 1\n", flags[i]);

    flag_sources[num_flags] = strdup(source);
    *out_num_sources = num_flags + 1;
    return flag_sources;
}

static void
_free_shader_flag_sources(char * flags[], size_t num_sources)
{
    for(size_t i = 0; i < num_sources; ++i)
        free(flags[i]);
    free(flags);
}

static GLuint
glsl_shader_from_string(GLenum kind, char const * shader_flags[], char const * source, char * * out_error_message)
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
glsl_program_from_shaders(GLuint vertex, GLuint fragment, char * * out_error_message)
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

char *
trixel_resource_filename(trixel_state t, char const * filename)
{
    char * full_filename;
    asprintf(&full_filename, "%s/%s", STATE(t)->resource_path, filename);
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
unmake_voxel_program(trixel_state t)
{
    glDetachShader(STATE(t)->voxel_program, STATE(t)->voxel_vertex_shader);
    glDetachShader(STATE(t)->voxel_program, STATE(t)->voxel_fragment_shader);

    glDeleteShader(STATE(t)->voxel_fragment_shader);
    glDeleteShader(STATE(t)->voxel_vertex_shader);
    glDeleteProgram(STATE(t)->voxel_program);

    STATE(t)->voxel_fragment_shader = 0;
    STATE(t)->voxel_vertex_shader = 0;
    STATE(t)->voxel_program = 0;
}

trixel_state
trixel_init_opengl(char const * resource_path, int viewport_width, int viewport_height, char const * shader_flags[], char * * out_error_message)
{
    trixel_state t = malloc(sizeof(struct trixel_internal_state));
    
    memset(t, 0, sizeof(struct trixel_internal_state));

    GLenum glew_error = glewInit();
    if(glew_error != GLEW_OK) {
        *out_error_message = strdup((char*)glewGetErrorString(glew_error));
        goto error;
    }

    if(!GLEW_VERSION_2_0
        || !GLEW_EXT_framebuffer_object
        || !GLEW_ARB_texture_float) {
        *out_error_message = strdup("Your OpenGL implementation doesn't conform to OpenGL 2.0.");
        goto error;
    }

    glClearColor(0.2, 0.2, 0.2, 1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glEnable(GL_DEPTH_TEST);
    glEnable(GL_CULL_FACE);

    if(glGetError() != GL_NO_ERROR) {
        *out_error_message = strdup("OpenGL had an error while setting up.");
        goto error;
    }

    trixel_reshape(t, viewport_width, viewport_height);

    STATE(t)->resource_path = strdup(resource_path);

    if(!trixel_update_shaders(t, shader_flags, out_error_message))
        goto error_after_save_resource_path;
    
    _gl_report_error("trixel_init_opengl");

    return t;

error_after_save_resource_path:
    free(STATE(t)->resource_path);
    free(t);
error:
    return NULL;
}

void
trixel_reshape(trixel_state t, int viewport_width, int viewport_height)
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
trixel_update_shaders(trixel_state t, char const *shader_flags[], char * * out_error_message)
{
    char *vertex_source_path = trixel_resource_filename(t, "voxel.vertex.glsl");
    char *fragment_source_path = trixel_resource_filename(t, "voxel.fragment.glsl");
    char *vertex_source   = contents_from_filename(vertex_source_path, NULL);
    char *fragment_source = contents_from_filename(fragment_source_path, NULL);
    if(!vertex_source || !fragment_source) {
        *out_error_message = strdup("Failed to load shader source for the voxmap renderer.");
    }

    GLuint voxel_vertex_shader = glsl_shader_from_string(GL_VERTEX_SHADER, shader_flags, vertex_source, out_error_message);
    if(!voxel_vertex_shader)
        goto error;
    GLuint voxel_fragment_shader = glsl_shader_from_string(GL_FRAGMENT_SHADER, shader_flags, fragment_source, out_error_message);
    if(!voxel_fragment_shader)
        goto error_after_vertex_shader;
    GLuint voxel_program = glsl_program_from_shaders(voxel_vertex_shader, voxel_fragment_shader, out_error_message);
    if(!voxel_program)
        goto error_after_fragment_shader;

    if(STATE(t)->voxel_program)
        unmake_voxel_program(t);
    STATE(t)->voxel_vertex_shader = voxel_vertex_shader;
    STATE(t)->voxel_fragment_shader = voxel_fragment_shader;
    STATE(t)->voxel_program = voxel_program;
    STATE(t)->voxel_uniforms.voxmap = glGetUniformLocation(STATE(t)->voxel_program, "voxmap");
    STATE(t)->voxel_uniforms.palette = glGetUniformLocation(STATE(t)->voxel_program, "palette");
    STATE(t)->voxel_uniforms.voxmap_size = glGetUniformLocation(STATE(t)->voxel_program, "voxmap_size");
    STATE(t)->voxel_uniforms.voxmap_size_inv = glGetUniformLocation(STATE(t)->voxel_program, "voxmap_size_inv");

    free(vertex_source);
    free(fragment_source);
    free(vertex_source_path);
    free(fragment_source_path);
    return 1;

error_after_fragment_shader:
    glDeleteShader(voxel_fragment_shader);
error_after_vertex_shader:
    glDeleteShader(voxel_vertex_shader);
error:
    free(vertex_source);
    free(fragment_source);
    free(vertex_source_path);
    free(fragment_source_path);
    return 0;
}

void
trixel_finish(trixel_state t)
{
    unmake_voxel_program(t);
    trixel_only_free(t);
}

void
trixel_only_free(trixel_state t)
{
    free(STATE(t)->resource_path);
    free(t);    
}

struct brick_header {
    char magic[4];
    uint16_t colors, width, height, depth; // XXX little endian!
};

trixel_brick *
trixel_read_brick(const void * data, size_t data_length, bool prepare, char * * out_error_message)
{
    const uint8_t * byte_data = (const uint8_t *)data;

    trixel_brick * brick = malloc(sizeof(trixel_brick));
    memset(brick, 0, sizeof(trixel_brick));

    struct brick_header * header = (struct brick_header *)data;

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

    brick->dimensions.x = (float)header->width;
    brick->dimensions.y = (float)header->height;
    brick->dimensions.z = (float)header->depth;

    brick->dimensions_inv.x = 1.0 / brick->dimensions.x;
    brick->dimensions_inv.y = 1.0 / brick->dimensions.y;
    brick->dimensions_inv.z = 1.0 / brick->dimensions.z;

    brick->palette_data = malloc(256 * 4);
    memset(brick->palette_data, 0, 256 * 4);
    memcpy(brick->palette_data + 4, byte_data + palette_offset, palette_length);
    brick->voxmap_data = malloc(voxmap_length);
    memcpy(brick->voxmap_data, byte_data + voxmap_offset, voxmap_length);

    if(prepare)
        trixel_prepare_brick(brick);

    return brick;

error:
    return NULL;
}

trixel_brick *
trixel_make_empty_brick(int w, int h, int d, bool prepare, char * * out_error_message)
{
    trixel_brick * brick = malloc(sizeof(trixel_brick));
    memset(brick, 0, sizeof(trixel_brick));

    brick->dimensions.x = (float)w;
    brick->dimensions.y = (float)h;
    brick->dimensions.z = (float)d;
    
    brick->dimensions_inv.x = 1.0 / brick->dimensions.x;
    brick->dimensions_inv.y = 1.0 / brick->dimensions.y;
    brick->dimensions_inv.z = 1.0 / brick->dimensions.z;

    brick->palette_data = malloc(256 * 4);
    memset(brick->palette_data, 0, 256 * 4);
    brick->voxmap_data = malloc(w * h * d);
    memset(brick->voxmap_data, 0, w * h * d);
    
    if(prepare)
        trixel_prepare_brick(brick);
    
    return brick;

error:
    return NULL;
}

void
trixel_prepare_brick(trixel_brick * brick)
{
    glGenTextures(1, &brick->voxmap_texture);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_3D, brick->voxmap_texture);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_S, GL_CLAMP);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_T, GL_CLAMP);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_R, GL_CLAMP);
    glTexImage3D(
        GL_TEXTURE_3D, 0, GL_LUMINANCE8,
        (GLsizei)brick->dimensions.x, (GLsizei)brick->dimensions.y, (GLsizei)brick->dimensions.z,
        0, GL_LUMINANCE, GL_UNSIGNED_BYTE, NULL
    );

    _gl_report_error("trixel_prepare_brick voxmap");

    glGenTextures(1, &brick->palette_texture);
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_1D, brick->palette_texture);
    glTexParameteri(GL_TEXTURE_1D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_1D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_1D, GL_TEXTURE_WRAP_S, GL_CLAMP);
    glTexImage1D(GL_TEXTURE_1D, 0, GL_RGBA8, 256, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);

    _gl_report_error("trixel_prepare_brick palette");

    trixel_update_brick_textures(brick);

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

bool
trixel_is_brick_prepared(trixel_brick * brick)
{
    return brick->vertex_buffer && brick->voxmap_texture && brick->palette_texture;
}

void
trixel_free_brick(trixel_brick * brick)
{
    if(brick->vertex_buffer)
        trixel_unprepare_brick(brick);
    trixel_only_free_brick(brick);
}

void
trixel_only_free_brick(trixel_brick * brick)
{
    free(brick->voxmap_data);
    free(brick->palette_data);
    free(brick);
}

void
trixel_unprepare_brick(trixel_brick * brick)
{
    glDeleteBuffers(1, &brick->vertex_buffer);
    glDeleteTextures(1, &brick->voxmap_texture);
    glDeleteTextures(1, &brick->palette_texture);
    brick->vertex_buffer = 0;
    brick->voxmap_texture = 0;
    brick->palette_texture = 0;
}

void
trixel_update_brick_textures(trixel_brick * brick)
{
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_3D, brick->voxmap_texture);
    /* Leopard nvidia driver bug seems to make glTexSubImage3D only update the z = 0 plane of the texture
    glTexSubImage3D(
        GL_TEXTURE_3D, 0,
        0, 0, 0,
        (GLsizei)brick->dimensions.x, (GLsizei)brick->dimensions.y, (GLsizei)brick->dimensions.z,
        GL_LUMINANCE, GL_UNSIGNED_BYTE, brick->voxmap_data
    );
    */
    glTexImage3D(
        GL_TEXTURE_3D, 0, GL_LUMINANCE8,
        (GLsizei)brick->dimensions.x, (GLsizei)brick->dimensions.y, (GLsizei)brick->dimensions.z,
        0, GL_LUMINANCE, GL_UNSIGNED_BYTE, brick->voxmap_data
    );

    _gl_report_error("trixel_update_brick_textures voxmap");

    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_1D, brick->palette_texture);
    glTexSubImage1D(GL_TEXTURE_1D, 0, 0, 256, GL_RGBA, GL_UNSIGNED_BYTE, brick->palette_data);

    _gl_report_error("trixel_update_brick_textures palette");
}

void *
trixel_write_brick(trixel_brick * brick, size_t * out_data_length)
{
    size_t colors = trixel_optimize_brick_palette(brick);
    
    size_t palette_length = colors * 4,
           voxmap_length = trixel_brick_voxmap_size(brick);
    
    *out_data_length = sizeof(struct brick_header) + palette_length + voxmap_length;
    
    unsigned char * data = malloc(*out_data_length);
    struct brick_header *header = (struct brick_header *)data;
    size_t palette_offset = sizeof(struct brick_header),
           voxmap_offset = palette_offset + palette_length;
           
    strncpy(header->magic, BRICK_MAGIC, 4);
    header->colors = colors;
    header->width  = (uint16_t)brick->dimensions.x;
    header->height = (uint16_t)brick->dimensions.y;
    header->depth  = (uint16_t)brick->dimensions.z;
    
    memcpy(data + palette_offset, brick->palette_data + 4, palette_length);
    memcpy(data + voxmap_offset,  brick->voxmap_data, voxmap_length);

    return data;
}

static void
_offset_voxmap_colors(trixel_brick * brick, int minIndex, int offset)
{
    size_t voxmap_size = trixel_brick_voxmap_size(brick);
    for(size_t i = 0; i < voxmap_size; ++i)
        if(brick->voxmap_data[i] >= minIndex)
            brick->voxmap_data[i] += offset;
}

static void
_change_voxmap_colors(trixel_brick * brick, unsigned new, unsigned old)
{
    size_t voxmap_size = trixel_brick_voxmap_size(brick);
    for(size_t i = 0; i < voxmap_size; ++i)
        if(brick->voxmap_data[i] == old)
            brick->voxmap_data[i] = new;
}

unsigned
trixel_optimize_brick_palette(trixel_brick * brick)
{
    unsigned i;
    unsigned top = 256;
    for(i = 0; i < top; ++i) {
        if(i != 0 && memcmp(trixel_brick_palette_color(brick, i), NULL_COLOR, 4) == 0)
            break;
        for(unsigned j = i + 1; j < top; ++j) {
            while(j < top && memcmp(trixel_brick_palette_color(brick, i), trixel_brick_palette_color(brick, j), 4) == 0) {
                _change_voxmap_colors(brick, i, j);
                trixel_remove_brick_palette_color(brick, j);
                --top;
            }
        }
    }
    if(trixel_is_brick_prepared(brick))
        trixel_update_brick_textures(brick);
    return i - 1;
}

unsigned char *
trixel_insert_brick_palette_color(trixel_brick * brick, int index)
{
    unsigned char * palette_color = trixel_brick_palette_color(brick, index);

    if(index != 0) {
        unsigned char * next_palette_color = palette_color + 4;
        memmove(next_palette_color, palette_color, (256 - index - 1) * 4);
        _offset_voxmap_colors(brick, index + 1, 1);
    }
    return palette_color;
}

void
trixel_remove_brick_palette_color(trixel_brick * brick, int index)
{
    if(index == 0)
        return;

    unsigned char * palette_color = trixel_brick_palette_color(brick, index),
                  * next_palette_color = palette_color + 4;
    memmove(palette_color, next_palette_color, (256 - index - 1) * 4);
    memset(trixel_brick_palette_color(brick, 255), 0, 4);
    _offset_voxmap_colors(brick, index + 1, -1);
}

void
trixel_draw_from_brick(trixel_state t, trixel_brick * brick)
{
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_3D, brick->voxmap_texture);
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_1D, brick->palette_texture);

    glUseProgram(STATE(t)->voxel_program);
    glUniform3fv(STATE(t)->voxel_uniforms.voxmap_size,     1, (GLfloat *)&brick->dimensions);
    glUniform3fv(STATE(t)->voxel_uniforms.voxmap_size_inv, 1, (GLfloat *)&brick->dimensions_inv);
    glUniform1i(STATE(t)->voxel_uniforms.voxmap,  0);
    glUniform1i(STATE(t)->voxel_uniforms.palette, 1);
}

void
trixel_draw_brick(trixel_state t, trixel_brick * brick)
{
    trixel_draw_from_brick(t, brick);

    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_NORMAL_ARRAY);

    glBindBuffer(GL_ARRAY_BUFFER, brick->vertex_buffer);

    glVertexPointer(3, GL_SHORT, 0, 0);
    glNormalPointer(GL_BYTE, 0, (void*)(6*4*3*sizeof(GLshort)));
    glDrawArrays(GL_QUADS, 0, 6*4);

    glBindBuffer(GL_ARRAY_BUFFER, 0);
}

trixel_brick *
trixel_read_brick_from_filename(char const * filename, bool prepare, char * * out_error_message)
{
    char *data;
    size_t data_length;
    data = contents_from_filename(filename, &data_length);
    if(!data) {
        asprintf(out_error_message, "Could not read from file '%s'.", filename);
        goto error;
    }

    trixel_brick *brick = trixel_read_brick(data, data_length, prepare, out_error_message);
    free(data);
    return brick;

error:
    return NULL;
}
