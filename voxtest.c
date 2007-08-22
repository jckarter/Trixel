#include <SDL.h>
#include <GL/glew.h>
#include <sys/time.h>

static const char g_palette[] = {
    0x00, 0x00, 0x00, 0x00,   0xFF, 0xFF, 0xFF, 0xFF,   0xFF, 0x00, 0x00, 0xFF,   0x00, 0xFF, 0x00, 0xFF,   // 0
    0x00, 0x00, 0xFF, 0xFF,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,

    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   // 16
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,

    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   // 32
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,

    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   // 48
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,

    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   // 64
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,

    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   // 80
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,

    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   // 96
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,

    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   // 112
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,

    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   // 128
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,

    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   // 144
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,

    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   // 160
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,

    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   // 176
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,

    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   // 192
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,

    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   // 208
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,

    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   // 224
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,

    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   // 240
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00,   0x00, 0x00, 0x00, 0x00
};

static const char g_voxmap[] = {
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 1, 1, 1, 1, 1, 1, 0,
    0, 1, 2, 2, 2, 2, 1, 0,
    0, 1, 2, 0, 0, 2, 1, 0,
    0, 1, 2, 0, 0, 2, 1, 0,
    0, 1, 2, 2, 2, 2, 1, 0,
    0, 1, 1, 1, 1, 1, 1, 0,
    0, 0, 0, 0, 0, 0, 0, 0,

    0, 1, 1, 1, 1, 1, 1, 0,
    1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 0, 0, 1, 1, 1,
    1, 1, 1, 0, 0, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1,
    0, 1, 1, 1, 1, 1, 1, 0,

    0, 1, 3, 3, 3, 3, 1, 0,
    1, 1, 1, 1, 1, 1, 1, 1,
    4, 1, 1, 1, 1, 1, 1, 4,
    4, 1, 1, 0, 0, 1, 1, 4,
    4, 1, 1, 0, 0, 1, 1, 4,
    4, 1, 1, 1, 1, 1, 1, 4,
    1, 1, 1, 1, 1, 1, 1, 1,
    0, 1, 3, 3, 3, 3, 1, 0,

    0, 1, 3, 0, 0, 3, 1, 0,
    1, 1, 1, 0, 0, 1, 1, 1,
    4, 1, 1, 0, 0, 1, 1, 4,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    4, 1, 1, 0, 0, 1, 1, 4,
    1, 1, 1, 0, 0, 1, 1, 1,
    0, 1, 3, 0, 0, 3, 1, 0,

    0, 1, 3, 0, 0, 3, 1, 0,
    1, 1, 1, 0, 0, 1, 1, 1,
    4, 1, 1, 0, 0, 1, 1, 4,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    4, 1, 1, 0, 0, 1, 1, 4,
    1, 1, 1, 0, 0, 1, 1, 1,
    0, 1, 3, 0, 0, 3, 1, 0,

    0, 1, 3, 3, 3, 3, 1, 0,
    1, 1, 1, 1, 1, 1, 1, 1,
    4, 1, 1, 1, 1, 1, 1, 4,
    4, 1, 1, 0, 0, 1, 1, 4,
    4, 1, 1, 0, 0, 1, 1, 4,
    4, 1, 1, 1, 1, 1, 1, 4,
    1, 1, 1, 1, 1, 1, 1, 1,
    0, 1, 3, 3, 3, 3, 1, 0,

    0, 1, 1, 1, 1, 1, 1, 0,
    1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 0, 0, 1, 1, 1,
    1, 1, 1, 0, 0, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1,
    0, 1, 1, 1, 1, 1, 1, 0,

    0, 0, 0, 0, 0, 0, 0, 0,
    0, 1, 1, 1, 1, 1, 1, 0,
    0, 1, 2, 2, 2, 2, 1, 0,
    0, 1, 2, 0, 0, 2, 1, 0,
    0, 1, 2, 0, 0, 2, 1, 0,
    0, 1, 2, 2, 2, 2, 1, 0,
    0, 1, 1, 1, 1, 1, 1, 0,
    0, 0, 0, 0, 0, 0, 0, 0
};

static struct state {
    GLhandleARB voxel_program, voxel_vertex_shader, voxel_fragment_shader;
    GLuint palette_texture, voxmap_texture;
    
    GLint eye_uniform, voxmap_uniform, palette_uniform, voxmap_size_uniform, voxmap_size_inv_uniform;
} g_state;

static SDL_Surface *
set_video_mode(int width, int height, char * * out_error_message)
{
    SDL_GL_SetAttribute(SDL_GL_RED_SIZE,   8);
    SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE, 8);
    SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE,  8);
    SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 32);
    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);

    SDL_Surface *screen = SDL_SetVideoMode(width, height, 32, SDL_OPENGL);

    if(!screen)
        goto error_from_sdl;

    GLenum glew_error = glewInit();
    if(glew_error != GLEW_OK) {
        *out_error_message = strdup((char*)glewGetErrorString(glew_error));
        goto error;
    }

    if(!GLEW_ARB_multitexture || !GLEW_ARB_shader_objects || !GLEW_ARB_shading_language_100) {
        *out_error_message = strdup("Shader support not available");
        goto error;
    }

    glViewport(0, 0, width, height);
    glClearColor(0.2, 0.2, 0.2, 1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glEnable(GL_DEPTH_TEST);
    glEnable(GL_CULL_FACE);

    float ambient[4] = {0.2f, 0.2f, 0.2f, 1.0f};
    glLightfv(GL_LIGHT0, GL_AMBIENT, ambient);

    if(glGetError() != GL_NO_ERROR) {
        *out_error_message = strdup("OpenGL error while initializing video mode");
        goto error;
    }
    
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    gluPerspective(45.0, (double)width/(double)height, 4.0, 512.0);

    SDL_GL_SwapBuffers();

    return screen;

error_from_sdl:
    *out_error_message = strdup(SDL_GetError());
error:
    return NULL;
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

static char *
contents_from_filename(char const *filename)
{
    FILE *f = fopen(filename, "rb");
    if(!f)
        goto error;

    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);

    char *buf = malloc(size+1);
    if(!buf)
        goto error_after_fopen_f;
    if(fread(buf, 1, size, f) != size)
        goto error_after_malloc_buf;
    fclose(f);

    buf[size] = '\0';
    return buf;

error_after_malloc_buf:
    free(buf);
error_after_fopen_f:
    fclose(f);
error:
    return NULL;
}

static int
make_textures(char * * out_error_message)
{
    glGenTextures(1, &g_state.palette_texture);
    glBindTexture(GL_TEXTURE_1D, g_state.palette_texture);
    glTexParameteri(GL_TEXTURE_1D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_1D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_1D, GL_TEXTURE_WRAP_S, GL_CLAMP);
    glTexImage1D(GL_TEXTURE_1D, 0, GL_RGBA8, 256, 0, GL_RGBA, GL_UNSIGNED_BYTE, g_palette);
    
    if(glGetError() != GL_NO_ERROR) {
        asprintf(out_error_message, "OpenGL error %X creating palette texture\n");
        goto error_after_palette_texture;
    }

    glGenTextures(1, &g_state.voxmap_texture);
    glBindTexture(GL_TEXTURE_3D, g_state.voxmap_texture);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_S, GL_CLAMP);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_T, GL_CLAMP);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_R, GL_CLAMP);
    glTexImage3D(GL_TEXTURE_3D, 0, GL_LUMINANCE8, 8, 8, 8, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, g_voxmap);
    
    GLenum gl_error = glGetError();
    if(gl_error != GL_NO_ERROR) {
        asprintf(out_error_message, "OpenGL error %X creating voxmap texture\n", gl_error);
        goto error_after_voxmap_texture;
    }

    return 1;

error_after_voxmap_texture:
    glDeleteTextures(1, &g_state.voxmap_texture);
error_after_palette_texture:
    glDeleteTextures(1, &g_state.palette_texture);
error:
    return 0;
}
    
static int
make_voxel_program(char * * out_error_message)
{
    char *vertex_source   = contents_from_filename("voxel.vertex.glsl");
    char *fragment_source = contents_from_filename("voxel.fragment.glsl");
    g_state.voxel_vertex_shader = glsl_shader_from_string(GL_VERTEX_SHADER_ARB, vertex_source, out_error_message);
    if(!g_state.voxel_vertex_shader)
        goto error;
    g_state.voxel_fragment_shader = glsl_shader_from_string(GL_FRAGMENT_SHADER_ARB, fragment_source, out_error_message);
    if(!g_state.voxel_fragment_shader)
        goto error_after_vertex_shader;
    g_state.voxel_program = glsl_program_from_shaders(g_state.voxel_vertex_shader, g_state.voxel_fragment_shader, out_error_message);
    if(!g_state.voxel_program)
        goto error_after_fragment_shader;
    
    g_state.eye_uniform = glGetUniformLocationARB(g_state.voxel_program, "eye");
    g_state.voxmap_uniform = glGetUniformLocationARB(g_state.voxel_program, "voxmap");
    g_state.palette_uniform = glGetUniformLocationARB(g_state.voxel_program, "palette");
    g_state.voxmap_size_uniform = glGetUniformLocationARB(g_state.voxel_program, "voxmap_size");
    g_state.voxmap_size_inv_uniform = glGetUniformLocationARB(g_state.voxel_program, "voxmap_size_inv");
    
    return 1;
    
error_after_fragment_shader:
    glDeleteObjectARB(g_state.voxel_fragment_shader);
error_after_vertex_shader:
    glDeleteObjectARB(g_state.voxel_vertex_shader);
error:
    free(vertex_source);
    free(fragment_source);
    return 0;
}

static void
remake_voxel_program()
{
    glDetachObjectARB(g_state.voxel_program, g_state.voxel_vertex_shader);
    glDetachObjectARB(g_state.voxel_program, g_state.voxel_fragment_shader);
    
    glDeleteObjectARB(g_state.voxel_fragment_shader);
    glDeleteObjectARB(g_state.voxel_vertex_shader);
    glDeleteObjectARB(g_state.voxel_program);
    
    char *error;
    if(!make_voxel_program(&error)) {
        fprintf(stderr, error);
        exit(0);
    }
}

static void
draw(float eye[], float yaw, float pitch)
{
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glMatrixMode(GL_PROJECTION);
    glPushMatrix();
    glRotatef(pitch, -1.0, 0.0, 0.0);
    glRotatef(yaw, 0.0, 1.0, 0.0);
    glTranslatef(-eye[0], -eye[1], -eye[2]);
    
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    glTranslatef(-4.0, -4.0, -4.0);
    
    glActiveTextureARB(GL_TEXTURE0_ARB);
    glBindTexture(GL_TEXTURE_3D, g_state.voxmap_texture);
    glActiveTextureARB(GL_TEXTURE1_ARB);
    glBindTexture(GL_TEXTURE_1D, g_state.palette_texture);
    
    glUseProgramObjectARB(g_state.voxel_program);
    glUniform4fvARB(g_state.eye_uniform, 1, eye);
    glUniform3fARB(g_state.voxmap_size_uniform, 8.0, 8.0, 8.0);
    glUniform3fARB(g_state.voxmap_size_inv_uniform, 1.0/8.0, 1.0/8.0, 1.0/8.0);
    glUniform1iARB(g_state.voxmap_uniform, 0);
    glUniform1iARB(g_state.palette_uniform, 1);
    
    glBegin(GL_QUADS);
    glVertex3f(0.0, 0.0, 0.0);
    glVertex3f(0.0, 8.0, 0.0);
    glVertex3f(8.0, 8.0, 0.0);
    glVertex3f(8.0, 0.0, 0.0);
    
    glVertex3f(8.0, 0.0, 0.0);
    glVertex3f(8.0, 8.0, 0.0);
    glVertex3f(8.0, 8.0, 8.0);
    glVertex3f(8.0, 0.0, 8.0);
    
    glVertex3f(0.0, 8.0, 8.0);
    glVertex3f(0.0, 0.0, 8.0);
    glVertex3f(8.0, 0.0, 8.0);
    glVertex3f(8.0, 8.0, 8.0);
    
    glVertex3f(0.0, 8.0, 0.0);
    glVertex3f(0.0, 0.0, 0.0);
    glVertex3f(0.0, 0.0, 8.0);
    glVertex3f(0.0, 8.0, 8.0);
    
    glVertex3f(0.0, 8.0, 0.0);
    glVertex3f(0.0, 8.0, 8.0);
    glVertex3f(8.0, 8.0, 8.0);
    glVertex3f(8.0, 8.0, 0.0);
    
    glVertex3f(0.0, 0.0, 8.0);
    glVertex3f(0.0, 0.0, 0.0);
    glVertex3f(8.0, 0.0, 0.0);
    glVertex3f(8.0, 0.0, 8.0);
    glEnd();
    
    glMatrixMode(GL_PROJECTION);
    glPopMatrix();
    SDL_GL_SwapBuffers();
}

static double
timeofday()
{
    struct timeval tm;
    gettimeofday(&tm, NULL);
    
    return (double)tm.tv_sec + (double)tm.tv_usec/1000000.0;
}

static void
benchmark(float eye[], float yaw, float pitch)
{
    double start = timeofday();
    for(int i = 0; i < 20; ++i) {
        draw(eye, yaw, pitch);
        putchar('.'); fflush(stdout);
    }
    double bench = timeofday() - start;
    printf("\r%f seconds to draw 20 frames (%f fps)\n", bench, 20.0/bench);
}

static void
main_loop()
{
    const float rotate_incr = 2.0, eye_incr = 2.0;
    
    float eye[4] = {0.0, 0.0, 128.0, 1.0}, yaw = 0.0, pitch = 0.0;
    
    SDL_Event e;
    while(SDL_WaitEvent(&e)) {
        switch(e.type) {
        case SDL_QUIT:
            return;
        case SDL_KEYDOWN:
            switch(e.key.keysym.sym) {
            case SDLK_UP:
                pitch += rotate_incr;
                break;
            case SDLK_DOWN:
                pitch -= rotate_incr;
                break;
            case SDLK_LEFT:
                yaw -= rotate_incr;
                break;
            case SDLK_RIGHT:
                yaw += rotate_incr;
                break;
            case SDLK_a:
                eye[0] -= eye_incr;
                break;
            case SDLK_e:
                eye[0] += eye_incr;
                break;
            case SDLK_o:
                eye[1] -= eye_incr;
                break;
            case SDLK_COMMA:
                eye[1] += eye_incr;
                break;
            case SDLK_p:
                eye[2] -= eye_incr;
                break;
            case SDLK_u:
                eye[2] += eye_incr;
                break;
            case SDLK_q:
                return;
            case SDLK_r:
                remake_voxel_program();
                printf("Remade voxel program\n");
                break;
            case SDLK_b:
                benchmark(eye, yaw, pitch);
                break;
            case SDLK_SPACE:
                eye[0] = 0.0; eye[1] = 0.0; eye[2] = 128.0;
                yaw = 0.0;
                pitch = 0.0;
                break;
            }
            break;
        }
        draw(eye, yaw, pitch);
    }
}

int
main(int argc, char** argv)
{
    char *error_message;
    SDL_Init(SDL_INIT_EVERYTHING);
    atexit(SDL_Quit);
    
    if(!set_video_mode(1024, 768, &error_message))
        goto error;
    if(!make_textures(&error_message))
        goto error;
    if(!make_voxel_program(&error_message))
        goto error;
    
    main_loop();
    return 0;

error:
    fprintf(stderr, "%s\n", error_message);
    free(error_message);
    return 1;
}
