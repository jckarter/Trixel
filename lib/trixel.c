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

#define NEAR_PLANE 4.0
#define FAR_PLANE  1024.0
#define FOV        2.41421

#define BRICK_MAGIC "Brik"
#define NULL_COLOR ((uint8_t *)"\0\0\0\0")

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

static struct trixel_render_path const *
_find_render_path(trixel_state t)
{
    static struct trixel_render_path const * render_paths[] = {
        &glsl_sm4_render_path,
        &arbfvp_render_path,
        NULL
    };
    
    if(!GLEW_ARB_texture_float)
        return NULL;

    for(struct trixel_render_path const * * path = render_paths; path; ++path)
        if((*path)->can_be_used(t))
            return *path;
    return NULL;
}

trixel_state
trixel_state_init(char const * resource_path, char * * out_error_message)
{
    trixel_state t = malloc(sizeof(struct trixel_internal_state));
    memset(t, 0, sizeof(struct trixel_internal_state));
    STATE(t)->render_path = _find_render_path(t);
    if(!STATE(t)->render_path) {
        *out_error_message = strdup("Your OpenGL implementation is not supported.");
        goto error_after_malloc_t;
    }
    STATE(t)->resource_path = strdup(resource_path);

    return t;

error_after_malloc_t:
    free(t);
    return NULL;
}

bool
trixel_init_glew(char * * out_error_message)
{
    GLenum glew_error = glewInit();
    if(glew_error != GLEW_OK) {
        *out_error_message = strdup((char*)glewGetErrorString(glew_error));
        return false;
    }
    return true;
}

trixel_state
trixel_init_opengl(char const * resource_path, int viewport_width, int viewport_height, int shader_flags, char * * out_error_message)
{
    if(!trixel_init_glew(out_error_message))
        goto error;

    trixel_state t = trixel_state_init(resource_path, out_error_message);
    if(!t)
        goto error;

    glClearColor(0.2, 0.2, 0.2, 1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glEnable(GL_DEPTH_TEST);
    glEnable(GL_CULL_FACE);

    if(glGetError() != GL_NO_ERROR) {
        *out_error_message = strdup("OpenGL had an error while setting up.");
        goto error_after_state_init;
    }

    trixel_reshape(t, viewport_width, viewport_height);

    if(!trixel_update_shaders(t, shader_flags, out_error_message))
        goto error_after_state_init;
    
    _gl_report_error("trixel_init_opengl");

    return t;

error_after_state_init:
    trixel_state_free(t);
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
trixel_update_shaders(trixel_state t, int shader_flags, char * * out_error_message)
{
    void * new_shaders = STATE(t)->render_path->make_shaders(t, shader_flags, out_error_message);
    
    if(new_shaders) {
        STATE(t)->render_path->delete_shaders(t);
        STATE(t)->shaders = new_shaders;
        STATE(t)->shader_flags = shader_flags;
    }
    return !!new_shaders;
}

void
trixel_finish(trixel_state t)
{
    STATE(t)->render_path->delete_shaders(t);
    trixel_state_free(t);
}

void
trixel_state_free(trixel_state t)
{
    free(STATE(t)->resource_path);
    free(t);    
}

struct brick_header {
    char magic[4];
    uint16_t colors, width, height, depth; // XXX little endian!
};

static void
_set_brick_metrics(trixel_brick * brick)
{
    brick->dimensions = POINT3_OF_INT3(brick->v.dimensions);
    brick->dimensions_inv = div_point3(POINT3(1.0,1.0,1.0), brick->dimensions);

    struct point3 normal_dimensions = add_point3(brick->dimensions, POINT3(1.0,1.0,1.0));
    brick->normal_translate = div_point3(POINT3(0.5,0.5,0.5), normal_dimensions);
    brick->normal_scale = div_point3(brick->dimensions, normal_dimensions);
}

trixel_brick *
trixel_read_brick(const void * data, size_t data_length, char * * out_error_message)
{
    const uint8_t * byte_data = (const uint8_t *)data;

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

    trixel_brick * brick = malloc(sizeof(trixel_brick) + header->width * header->height * header->depth);
    memset(brick, 0, sizeof(trixel_brick));

    brick->v.dimensions = INT3(header->width, header->height, header->depth);
    _set_brick_metrics(brick);

    memcpy(brick->palette_data + 4, byte_data + palette_offset, palette_length);
    memcpy(brick->v.data, byte_data + voxmap_offset, voxmap_length);

    return brick;

error:
    return NULL;
}

trixel_brick *
_trixel_make_brick(int w, int h, int d, bool solid, char * * out_error_message)
{
    trixel_brick * brick = malloc(sizeof(trixel_brick) + w*h*d);
    memset(brick, 0, sizeof(trixel_brick));

    brick->v.dimensions = INT3(w, h, d);
    _set_brick_metrics(brick);

    uint8_t fill = solid ? 1 : 0;

    if(solid)
        memset(trixel_brick_palette_color(brick, 1), 0xFF, 4);
    memset(brick->v.data, fill, w * h * d);
    
    return brick;

error:
    return NULL;
}

trixel_brick *
trixel_make_empty_brick(int w, int h, int d, char * * out_error_message)
{
    return _trixel_make_brick(w, h, d, false, out_error_message);
}

trixel_brick *
trixel_make_solid_brick(int w, int h, int d, char * * out_error_message)
{
    return _trixel_make_brick(w, h, d, true, out_error_message);
}

trixel_brick *
trixel_copy_brick(trixel_brick const * brick, char * * out_error_message)
{
    trixel_brick * new_brick = trixel_make_empty_brick(
        brick->v.dimensions.x, brick->v.dimensions.y, brick->v.dimensions.z,
        out_error_message
    );
    if(new_brick) {
        memcpy(new_brick, brick, sizeof(brick) + voxmap_size(&brick->v));
    }
    return new_brick;
}

void
trixel_prepare_brick(trixel_brick * brick, trixel_state t)
{
    brick->t = t;

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
        brick->v.dimensions.x, brick->v.dimensions.y, brick->v.dimensions.z,
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

    glGenTextures(1, &brick->normal_texture);
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_3D, brick->normal_texture);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_S, GL_CLAMP);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_T, GL_CLAMP);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_R, GL_CLAMP);
    glTexImage3D(
        GL_TEXTURE_3D, 0, GL_RGB16F_ARB,
        brick->v.dimensions.x + 1, brick->v.dimensions.y + 1, brick->v.dimensions.z + 1,
        0, GL_RGB, GL_FLOAT, NULL
    );

    trixel_update_brick_textures(brick);
    glActiveTexture(GL_TEXTURE0);
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
    brick->t = NULL;
}

static inline void
_clamp_neighbors(trixel_brick * brick, int * x, int * y, int * z)
{
    int neighbor_flags = brick->neighbor_flags;
    if (neighbor_flags == 0) return;

    if ((neighbor_flags & TRIXEL_NEIGHBOR_NEGX_FLAG) && (*x < 0))
        *x = 0;
    if ((neighbor_flags & TRIXEL_NEIGHBOR_NEGY_FLAG) && (*y < 0))
        *y = 0;
    if ((neighbor_flags & TRIXEL_NEIGHBOR_NEGZ_FLAG) && (*z < 0))
        *z = 0;

    if ((neighbor_flags & TRIXEL_NEIGHBOR_POSX_FLAG) && (*x >= brick->v.dimensions.x))
        *x = brick->v.dimensions.x - 1;
    if ((neighbor_flags & TRIXEL_NEIGHBOR_POSY_FLAG) && (*y >= brick->v.dimensions.y))
        *y = brick->v.dimensions.y - 1;
    if ((neighbor_flags & TRIXEL_NEIGHBOR_POSZ_FLAG) && (*z >= brick->v.dimensions.z))
        *z = brick->v.dimensions.z - 1;
}

static inline uint8_t
_clipped_voxel(trixel_brick * brick, int x, int y, int z)
{
    _clamp_neighbors(brick, &x, &y, &z);
    return x >= 0 && y >= 0 && z >= 0
        && x < brick->v.dimensions.x && y < brick->v.dimensions.y && z < brick->v.dimensions.z
            ? *trixel_brick_voxel(brick, x, y, z)
            : 0;
}

void
_calculate_normal(trixel_brick * brick, int x, int y, int z, struct point3 * out_normal, uint8_t * out_neighbors)
{
    static const struct point3 normalvectors[8] = {
        { -1, -1, -1 },
        { -1, -1,  1 },
        { -1,  1, -1 },
        { -1,  1,  1 },
        {  1, -1, -1 },
        {  1, -1,  1 },
        {  1,  1, -1 },
        {  1,  1,  1 }
    };
    static const struct int3 offsets[8] = {
        { -1, -1, -1 },
        { -1, -1,  0 },
        { -1,  0, -1 },
        { -1,  0,  0 },
        {  0, -1, -1 },
        {  0, -1,  0 },
        {  0,  0, -1 },
        {  0,  0,  0 }        
    };
    static const struct { uint8_t x, y, z; } neighbors[8] = {
        { TRIXEL_NEIGHBOR_NEGX, TRIXEL_NEIGHBOR_NEGY, TRIXEL_NEIGHBOR_NEGZ },
        { TRIXEL_NEIGHBOR_NEGX, TRIXEL_NEIGHBOR_NEGY, TRIXEL_NEIGHBOR_POSZ },
        { TRIXEL_NEIGHBOR_NEGX, TRIXEL_NEIGHBOR_POSY, TRIXEL_NEIGHBOR_NEGZ },
        { TRIXEL_NEIGHBOR_NEGX, TRIXEL_NEIGHBOR_POSY, TRIXEL_NEIGHBOR_POSZ },
        { TRIXEL_NEIGHBOR_POSX, TRIXEL_NEIGHBOR_NEGY, TRIXEL_NEIGHBOR_NEGZ },
        { TRIXEL_NEIGHBOR_POSX, TRIXEL_NEIGHBOR_NEGY, TRIXEL_NEIGHBOR_POSZ },
        { TRIXEL_NEIGHBOR_POSX, TRIXEL_NEIGHBOR_POSY, TRIXEL_NEIGHBOR_NEGZ },
        { TRIXEL_NEIGHBOR_POSX, TRIXEL_NEIGHBOR_POSY, TRIXEL_NEIGHBOR_POSZ }
    };
    
    for(int i = 0; i < 8; ++i)
        if(!_clipped_voxel(brick, x + offsets[i].x, y + offsets[i].y, z + offsets[i].z))
            add_to_point3(out_normal, normalvectors[i]);
        else {
            ++out_neighbors[neighbors[i].x];
            ++out_neighbors[neighbors[i].y];
            ++out_neighbors[neighbors[i].z];
        }
}

void
_log_normal_data(
    int w, int h, int d,
    struct point3 raw_normal[d][h][w],
    uint8_t neighbors[d][h][w][6],
    struct point3 smooth_normal[d][h][w]
)
{
    fprintf(stderr, "raw normals:\n  ");
    for(int z = 0; z < d; ++z) {
        for(int y = 0; y < h; ++y) {
            for(int x = 0; x < w; ++x) {
                fprintf(stderr, "%10.8f,%10.8f,%10.8f ", raw_normal[z][y][x].x,
                                                         raw_normal[z][y][x].y,
                                                         raw_normal[z][y][x].z);
            }
            fprintf(stderr, "\n  ");
        }
        fprintf(stderr, "\n  ");
    }
    
    fprintf(stderr, "neighbors:\n  ");
    for(int z = 0; z < d; ++z) {
        for(int y = 0; y < h; ++y) {
            for(int x = 0; x < w; ++x) {
                fprintf(stderr, "%d,%d,%d,%d,%d,%d ", neighbors[z][y][x][0],
                                                      neighbors[z][y][x][1],
                                                      neighbors[z][y][x][2],
                                                      neighbors[z][y][x][3],
                                                      neighbors[z][y][x][4],
                                                      neighbors[z][y][x][5]);
            }
            fprintf(stderr, "\n  ");
        }
        fprintf(stderr, "\n  ");
    }            

    fprintf(stderr, "smooth normals:\n  ");
    for(int z = 0; z < d; ++z) {
        for(int y = 0; y < h; ++y) {
            for(int x = 0; x < w; ++x) {
                fprintf(stderr, "%10.8f,%10.8f,%10.8f ", smooth_normal[z][y][x].x,
                                                         smooth_normal[z][y][x].y,
                                                         smooth_normal[z][y][x].z);
            }
            fprintf(stderr, "\n  ");
        }
        fprintf(stderr, "\n  ");
    }
}

void
_generate_normal_texture(trixel_brick * brick)
{
    int normals_w = brick->v.dimensions.x + 1,
        normals_h = brick->v.dimensions.y + 1,
        normals_d = brick->v.dimensions.z + 1,
        normals_size = normals_w * normals_h * normals_d;
    uint8_t raw_neighbors[normals_d][normals_h][normals_w][6];
    struct point3 raw_normal_texture_data[normals_d][normals_h][normals_w],
                  normal_texture_data[normals_d][normals_h][normals_w];
    
    memset(raw_neighbors, 0, sizeof(uint8_t) * normals_size * 6);
    memset(raw_normal_texture_data, 0, sizeof(struct point3) * normals_size);
    
    for(int z = 0; z < normals_d; ++z)
        for(int y = 0; y < normals_h; ++y)
            for(int x = 0; x < normals_w; ++x)
                _calculate_normal(
                    brick, x, y, z,
                    &raw_normal_texture_data[z][y][x],
                    &raw_neighbors[z][y][x][0]
                );
    memcpy(normal_texture_data, raw_normal_texture_data, sizeof(float) * normals_size * 3);
    for(int z = 0; z < normals_d; ++z)
        for(int y = 0; y < normals_h; ++y)
            for(int x = 0; x < normals_w; ++x) {
                if(raw_neighbors[z][y][x][TRIXEL_NEIGHBOR_POSX] % 4)
                    add_to_point3(&normal_texture_data[z][y][x], raw_normal_texture_data[z][y][x+1 > normals_w ? normals_w : x+1]);
                if(raw_neighbors[z][y][x][TRIXEL_NEIGHBOR_POSY] % 4)
                    add_to_point3(&normal_texture_data[z][y][x], raw_normal_texture_data[z][y+1 > normals_h ? normals_h : y+1][x]);
                if(raw_neighbors[z][y][x][TRIXEL_NEIGHBOR_POSZ] % 4)
                    add_to_point3(&normal_texture_data[z][y][x], raw_normal_texture_data[z+1 > normals_d ? normals_d : z+1][y][x]);
                if(raw_neighbors[z][y][x][TRIXEL_NEIGHBOR_NEGX] % 4)
                    add_to_point3(&normal_texture_data[z][y][x], raw_normal_texture_data[z][y][x-1 < 0 ? 0 : x-1]);
                if(raw_neighbors[z][y][x][TRIXEL_NEIGHBOR_NEGY] % 4)
                    add_to_point3(&normal_texture_data[z][y][x], raw_normal_texture_data[z][y-1 < 0 ? 0 : y-1][x]);
                if(raw_neighbors[z][y][x][TRIXEL_NEIGHBOR_NEGZ] % 4)
                    add_to_point3(&normal_texture_data[z][y][x], raw_normal_texture_data[z-1 < 0 ? 0 : z-1][y][x]);
            }

    //_log_normal_data(
    //    normals_w, normals_h, normals_d,
    //    raw_normal_texture_data, raw_neighbors, normal_texture_data
    //);

    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_3D, brick->normal_texture);
    glTexImage3D(
        GL_TEXTURE_3D, 0, GL_RGB16F_ARB,
        normals_w, normals_h, normals_d,
        0, GL_RGB, GL_FLOAT, (float*)normal_texture_data
    );

    _gl_report_error("trixel_update_brick_textures normal");
    glActiveTexture(GL_TEXTURE0);
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
        brick->v.dimensions.x, brick->v.dimensions.y, brick->v.dimensions.z,
        GL_LUMINANCE, GL_UNSIGNED_BYTE, brick->v.data
    );
    */
    glTexImage3D(
        GL_TEXTURE_3D, 0, GL_LUMINANCE8,
        brick->v.dimensions.x, brick->v.dimensions.y, brick->v.dimensions.z,
        0, GL_LUMINANCE, GL_UNSIGNED_BYTE, brick->v.data
    );

    _gl_report_error("trixel_update_brick_textures voxmap");

    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_1D, brick->palette_texture);
    glTexSubImage1D(GL_TEXTURE_1D, 0, 0, 256, GL_RGBA, GL_UNSIGNED_BYTE, brick->palette_data);

    _gl_report_error("trixel_update_brick_textures palette");

    _generate_normal_texture(brick);
    
    STATE(brick->t)->render_path->make_vertex_buffer_for_brick(brick->t, brick);
    glActiveTexture(GL_TEXTURE0);
}

void *
trixel_write_brick(trixel_brick * brick, size_t * out_data_length)
{
    size_t colors = trixel_optimize_brick_palette(brick);
    
    size_t palette_length = colors * 4,
           voxmap_length = trixel_brick_voxmap_size(brick);
    
    *out_data_length = sizeof(struct brick_header) + palette_length + voxmap_length;
    
    uint8_t * data = malloc(*out_data_length);
    struct brick_header *header = (struct brick_header *)data;
    size_t palette_offset = sizeof(struct brick_header),
           voxmap_offset = palette_offset + palette_length;
           
    strncpy(header->magic, BRICK_MAGIC, 4);
    header->colors = colors;
    header->width  = (uint16_t)brick->v.dimensions.x;
    header->height = (uint16_t)brick->v.dimensions.y;
    header->depth  = (uint16_t)brick->v.dimensions.z;
    
    memcpy(data + palette_offset, brick->palette_data + 4, palette_length);
    memcpy(data + voxmap_offset,  brick->v.data, voxmap_length);

    return data;
}

static void
_offset_voxmap_colors(trixel_brick * brick, int minIndex, int offset)
{
    size_t voxmap_size = trixel_brick_voxmap_size(brick);
    for(size_t i = 0; i < voxmap_size; ++i)
        if(brick->v.data[i] >= minIndex)
            brick->v.data[i] += offset;
}

static void
_change_voxmap_colors(trixel_brick * brick, unsigned new, unsigned old)
{
    size_t voxmap_size = trixel_brick_voxmap_size(brick);
    for(size_t i = 0; i < voxmap_size; ++i)
        if(brick->v.data[i] == old)
            brick->v.data[i] = new;
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

uint8_t *
trixel_insert_brick_palette_color(trixel_brick * brick, int index)
{
    uint8_t * palette_color = trixel_brick_palette_color(brick, index);

    if(index != 0) {
        uint8_t * next_palette_color = palette_color + 4;
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

    uint8_t * palette_color = trixel_brick_palette_color(brick, index),
            * next_palette_color = palette_color + 4;
    memmove(palette_color, next_palette_color, (256 - index - 1) * 4);
    memset(trixel_brick_palette_color(brick, 255), 0, 4);
    _offset_voxmap_colors(brick, index + 1, -1);
}

void
trixel_draw_from_brick(trixel_brick * brick)
{
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_3D, brick->voxmap_texture);
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_1D, brick->palette_texture);
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_3D, brick->normal_texture);

    STATE(brick->t)->render_path->draw_from_brick(brick->t, brick);
}

void
trixel_finish_draw(trixel_state t)
{
    STATE(t)->render_path->finish_draw(t);
    _gl_report_error("finish draw");
}

void
trixel_draw_brick(trixel_brick * brick)
{
    trixel_draw_from_brick(brick);

    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_NORMAL_ARRAY);

    glBindBuffer(GL_ARRAY_BUFFER, brick->vertex_buffer);

    glVertexPointer(3, GL_FLOAT, 0, 0);
    glNormalPointer(GL_FLOAT, 0, (void*)(brick->num_vertices*3*sizeof(GLfloat)));
    glDrawArrays(GL_QUADS, 0, brick->num_vertices);

    glBindBuffer(GL_ARRAY_BUFFER, 0);
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

void
trixel_light_param(trixel_state t, GLuint light, int param, GLfloat * value)
{
    STATE(t)->render_path->set_light_param(t, light, param, value);
}
