// Tesselated renderer with ARB_fragment_program/ARB_vertex_program

#include "trixel.h"
#include "trixel_internal.h"
#include "voxmap.h"
#include <GL/glew.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum arbfvp_fragment_program_params {
    ARBFVP_FRAGMENT_LIGHT0_POSITION  = TRIXEL_LIGHT_PARAM_POSITION,
    ARBFVP_FRAGMENT_LIGHT0_AMBIENT   = TRIXEL_LIGHT_PARAM_AMBIENT,
    ARBFVP_FRAGMENT_LIGHT0_DIFFUSE   = TRIXEL_LIGHT_PARAM_DIFFUSE
};

enum arbfvp_vertex_program_params {
    ARBFVP_VERTEX_VOXMAP_SIZE_INV,
    ARBFVP_VERTEX_NORMAL_SCALE,
    ARBFVP_VERTEX_NORMAL_TRANSLATE
};

struct arbfvp_shaders {
    GLuint vertex_program, fragment_program;
};

static inline struct arbfvp_shaders *
ARBFVP(trixel_state t)
{
    return (struct arbfvp_shaders *)(STATE(t)->shaders);
}

static bool
arbfvp_can_use_render_path(trixel_state t)
{
    return GLEW_ARB_fragment_program && GLEW_ARB_vertex_program;
}

static GLuint
_arb_program_from_string(GLenum kind, int shader_flags, char const * source, size_t source_length, char * * out_error_message)
{
    GLuint program;
    glGenProgramsARB(1, &program);
    glBindProgramARB(kind, program);
    glProgramStringARB(kind, GL_PROGRAM_FORMAT_ASCII_ARB, source_length, source);

    GLint error_position;
    glGetIntegerv(GL_PROGRAM_ERROR_POSITION_ARB, &error_position);
    if(error_position >= 0) {
        const GLubyte * error_string = glGetString(GL_PROGRAM_ERROR_STRING_ARB);
        asprintf(out_error_message, "Error in program at position %d: %s", error_position, error_string);
        goto error;
    }

    glBindProgramARB(kind, 0);

    return program;

error:
    glBindProgramARB(kind, 0);
    glDeleteProgramsARB(1, &program);
    return 0;
}

static void *
arbfvp_make_shaders(trixel_state t, int shader_flags, char * * out_error_message)
{
    struct arbfvp_shaders * shaders = malloc(sizeof(struct arbfvp_shaders));

    char *vertex_source_path = trixel_resource_filename(t, "shaders/arbfvp/voxel.arbvp");
    char *fragment_source_path = trixel_resource_filename(t, "shaders/arbfvp/voxel.arbfp");

    size_t vertex_source_length, fragment_source_length;
    char *vertex_source   = contents_from_filename(vertex_source_path, &vertex_source_length);
    char *fragment_source = contents_from_filename(fragment_source_path, &fragment_source_length);
    if(!vertex_source || !fragment_source) {
        *out_error_message = strdup("Failed to load shader source for the voxmap renderer.");
        goto error;
    }

    shaders->vertex_program = _arb_program_from_string(GL_VERTEX_PROGRAM_ARB, shader_flags, vertex_source, vertex_source_length, out_error_message);
    if(!shaders->vertex_program)
        goto error;
    shaders->fragment_program = _arb_program_from_string(GL_FRAGMENT_PROGRAM_ARB, shader_flags, fragment_source, fragment_source_length, out_error_message);
    if(!shaders->fragment_program)
        goto error_after_vertex_program;

    free(vertex_source);
    free(fragment_source);
    free(vertex_source_path);
    free(fragment_source_path);

    return shaders;

error_after_vertex_program:
    glDeleteProgramsARB(1, &shaders->vertex_program);
error:
    if(vertex_source) free(vertex_source);
    if(fragment_source) free(fragment_source);
    free(vertex_source_path);
    free(fragment_source_path);
    free(shaders);
    return NULL;
}

static void
arbfvp_delete_shaders(trixel_state t)
{
    struct arbfvp_shaders * shaders = ARBFVP(t);
    if(shaders) {
        glDeleteProgramsARB(1, &shaders->vertex_program);
        glDeleteProgramsARB(1, &shaders->fragment_program);
        free(shaders);
    }
}

static void
arbfvp_set_light_param(trixel_state t, GLuint light, int param, GLfloat * value)
{
    // XXX multiple lights?
    glBindProgramARB(GL_FRAGMENT_PROGRAM_ARB, ARBFVP(t)->fragment_program);
    glProgramLocalParameter4fvARB(GL_FRAGMENT_PROGRAM_ARB, param, value);
    glBindProgramARB(GL_FRAGMENT_PROGRAM_ARB, 0);
}

static void
arbfvp_make_vertex_buffer_for_brick(trixel_state t, trixel_brick * brick)
{
    GLshort width2  = (GLshort)brick->v.dimensions.x / 2,
            height2 = (GLshort)brick->v.dimensions.y / 2,
            depth2  = (GLshort)brick->v.dimensions.z / 2;

    voxmap * mask = voxmap_maskify(&brick->v, 1),
           * xface, * xa,
           * yface, * ya,
           * zface, * za;
    struct int3 xdim = add_int3(mask->dimensions, INT3(1,0,0)),
                ydim = add_int3(mask->dimensions, INT3(0,1,0)),
                zdim = add_int3(mask->dimensions, INT3(0,0,1));

    xa = voxmap_make(xdim);
    xface = voxmap_make(xdim);
    voxmap_copy(xa,    INT3(0,0,0), mask);
    voxmap_copy(xface, INT3(1,0,0), mask);
    voxmap_sub (xface, xa);
    voxmap_free(xa);
 
    ya = voxmap_make(ydim);
    yface = voxmap_make(ydim);
    voxmap_copy(ya,    INT3(0,0,0), mask);
    voxmap_copy(yface, INT3(0,1,0), mask);
    voxmap_sub (yface, ya);
    voxmap_free(ya);
 
    za = voxmap_make(zdim);
    zface = voxmap_make(zdim);
    voxmap_copy(za,    INT3(0,0,0), mask);
    voxmap_copy(zface, INT3(0,0,1), mask);
    voxmap_sub (zface, za);
    voxmap_free(za);

    voxmap_free(mask);

    int num_vertices = 4 * (voxmap_count(xface) + voxmap_count(yface) + voxmap_count(zface)),
        buffer_size = 3 * num_vertices * (sizeof(GLshort)+sizeof(GLbyte));
    void * buffer = malloc(buffer_size);
    GLshort * vertices = buffer;
    GLbyte  * normals  = (GLbyte*)(buffer + num_vertices);

    for(int z = 0; z < xdim.z; ++z)
        for(int y = 0; y < xdim.y; ++y)
            for(int x = 0; x < xdim.x; ++x) {
                if(*voxmap_voxel(xface, x, y, z) == 1) {
                    vertices[ 0] = x  -width2; vertices[ 1] = y+1-height2; vertices[ 2] = z  -depth2;
                    vertices[ 3] = x  -width2; vertices[ 4] = y+1-height2; vertices[ 5] = z+1-depth2;
                    vertices[ 6] = x  -width2; vertices[ 7] = y  -height2; vertices[ 8] = z+1-depth2;
                    vertices[ 9] = x  -width2; vertices[10] = y  -height2; vertices[11] = z  -depth2;
                    vertices += 12;

                    normals[ 0] = 127; normals[ 1] = 0; normals[ 2] = 0;
                    normals[ 3] = 127; normals[ 4] = 0; normals[ 5] = 0;
                    normals[ 6] = 127; normals[ 7] = 0; normals[ 8] = 0;
                    normals[ 9] = 127; normals[10] = 0; normals[11] = 0;
                    normals += 12;
                }
                else if(*voxmap_voxel(xface, x, y, z) == (uint8_t)-1) {
                    vertices[ 0] = x  -width2; vertices[ 1] = y  -height2; vertices[ 2] = z  -depth2;
                    vertices[ 3] = x  -width2; vertices[ 4] = y  -height2; vertices[ 5] = z+1-depth2;
                    vertices[ 6] = x  -width2; vertices[ 7] = y+1-height2; vertices[ 8] = z+1-depth2;
                    vertices[ 9] = x  -width2; vertices[10] = y+1-height2; vertices[11] = z  -depth2;
                    vertices += 12;

                    normals[ 0] = -128; normals[ 1] = 0; normals[ 2] = 0;
                    normals[ 3] = -128; normals[ 4] = 0; normals[ 5] = 0;
                    normals[ 6] = -128; normals[ 7] = 0; normals[ 8] = 0;
                    normals[ 9] = -128; normals[10] = 0; normals[11] = 0;
                    normals += 12;
                }

                if(*voxmap_voxel(yface, z, x, y) == 1) {
                    vertices[ 0] = z  -width2; vertices[ 1] = x  -height2; vertices[ 2] = y+1-depth2;
                    vertices[ 3] = z+1-width2; vertices[ 4] = x  -height2; vertices[ 5] = y+1-depth2;
                    vertices[ 6] = z+1-width2; vertices[ 7] = x  -height2; vertices[ 8] = y  -depth2;
                    vertices[ 9] = z  -width2; vertices[10] = x  -height2; vertices[11] = y  -depth2;
                    vertices += 12;

                    normals[ 0] = 0; normals[ 1] = 127; normals[ 2] = 0;
                    normals[ 3] = 0; normals[ 4] = 127; normals[ 5] = 0;
                    normals[ 6] = 0; normals[ 7] = 127; normals[ 8] = 0;
                    normals[ 9] = 0; normals[10] = 127; normals[11] = 0;
                    normals += 12;
                }
                else if(*voxmap_voxel(yface, z, x, y) == (uint8_t)-1) {
                    vertices[ 0] = z  -width2; vertices[ 1] = x  -height2; vertices[ 2] = y  -depth2;
                    vertices[ 3] = z+1-width2; vertices[ 4] = x  -height2; vertices[ 5] = y  -depth2;
                    vertices[ 6] = z+1-width2; vertices[ 7] = x  -height2; vertices[ 8] = y+1-depth2;
                    vertices[ 9] = z  -width2; vertices[10] = x  -height2; vertices[11] = y+1-depth2;
                    vertices += 12;

                    normals[ 0] = 0; normals[ 1] = -128; normals[ 2] = 0;
                    normals[ 3] = 0; normals[ 4] = -128; normals[ 5] = 0;
                    normals[ 6] = 0; normals[ 7] = -128; normals[ 8] = 0;
                    normals[ 9] = 0; normals[10] = -128; normals[11] = 0;
                    normals += 12;
                }

                if(*voxmap_voxel(zface, y, z, x) == 1) {
                    vertices[ 0] = y+1-width2; vertices[ 1] = z  -height2; vertices[ 2] = x  -depth2;
                    vertices[ 3] = y+1-width2; vertices[ 4] = z+1-height2; vertices[ 5] = x  -depth2;
                    vertices[ 6] = y  -width2; vertices[ 7] = z+1-height2; vertices[ 8] = x  -depth2;
                    vertices[ 9] = y  -width2; vertices[10] = z  -height2; vertices[11] = x  -depth2;
                    vertices += 12;

                    normals[ 0] = 0; normals[ 1] = 0; normals[ 2] = 127;
                    normals[ 3] = 0; normals[ 4] = 0; normals[ 5] = 127;
                    normals[ 6] = 0; normals[ 7] = 0; normals[ 8] = 127;
                    normals[ 9] = 0; normals[10] = 0; normals[11] = 127;
                    normals += 12;
                }
                else if(*voxmap_voxel(zface, y, z, x) == (uint8_t)-1) {
                    vertices[ 0] = y  -width2; vertices[ 1] = z  -height2; vertices[ 2] = x  -depth2;
                    vertices[ 3] = y  -width2; vertices[ 4] = z+1-height2; vertices[ 5] = x  -depth2;
                    vertices[ 6] = y+1-width2; vertices[ 7] = z+1-height2; vertices[ 8] = x  -depth2;
                    vertices[ 9] = y+1-width2; vertices[10] = z  -height2; vertices[11] = x  -depth2;
                    vertices += 12;

                    normals[ 0] = 0; normals[ 1] = 0; normals[ 2] = -128;
                    normals[ 3] = 0; normals[ 4] = 0; normals[ 5] = -128;
                    normals[ 6] = 0; normals[ 7] = 0; normals[ 8] = -128;
                    normals[ 9] = 0; normals[10] = 0; normals[11] = -128;
                    normals += 12;
                }
            }
    voxmap_free(xface);
    voxmap_free(yface);
    voxmap_free(zface);

    glGenBuffers(1, &brick->vertex_buffer);
    glBindBuffer(GL_ARRAY_BUFFER, brick->vertex_buffer);
    glBufferData(GL_ARRAY_BUFFER, buffer_size, buffer, GL_STATIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    free(buffer);

    brick->num_vertices = num_vertices;
}

static void
arbfvp_draw_from_brick(trixel_state t, trixel_brick * brick)
{
    struct arbfvp_shaders * shaders = ARBFVP(t);
    
    //glBindProgramARB(GL_VERTEX_PROGRAM_ARB, shaders->vertex_program);
    //glBindProgramARB(GL_FRAGMENT_PROGRAM_ARB, shaders->fragment_program);

    //glProgramLocalParameter4fvARB(GL_VERTEX_PROGRAM_ARB, ARBFVP_VERTEX_NORMAL_SCALE,     (GLfloat*)&brick->normal_scale);
    //glProgramLocalParameter4fvARB(GL_VERTEX_PROGRAM_ARB, ARBFVP_VERTEX_NORMAL_TRANSLATE, (GLfloat*)&brick->normal_translate);
}

static void
arbfvp_finish_draw(trixel_state t)
{
    glBindProgramARB(GL_VERTEX_PROGRAM_ARB, 0);
    glBindProgramARB(GL_FRAGMENT_PROGRAM_ARB, 0);
}

struct trixel_render_path const arbfvp_render_path = {
    "ARB_fragment_program",
    arbfvp_can_use_render_path,
    arbfvp_make_shaders,
    arbfvp_delete_shaders,
    arbfvp_set_light_param,
    arbfvp_make_vertex_buffer_for_brick,
    arbfvp_draw_from_brick,
    arbfvp_finish_draw
};
