#include <SDL.h>
#include <GL/glew.h>
#include <sys/time.h>

#include "trixel.h"

static trixel_brick * g_brick;

static int g_flags = TRIXEL_LIGHTING | TRIXEL_SMOOTH_SHADING;

static trixel_state
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

    trixel_state t = trixel_init_opengl("..", width, height, g_flags, out_error_message);
    if(!t)
        goto error;

    return t;

error_from_sdl:
    *out_error_message = strdup(SDL_GetError());
error:
    return NULL;
}

static void
draw(trixel_state t, float eye[], float yaw, float pitch)
{
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    GLfloat ambient[4] = { 0.2, 0.2, 0.2, 1.0 };
    GLfloat diffuse[4] = { 0.8, 0.8, 0.8, 1.0 };
    GLfloat position[4] = { 64.0, 32.0, 64.0, 1.0 };

    trixel_light_param(t, 0, TRIXEL_LIGHT_PARAM_AMBIENT, ambient);
    trixel_light_param(t, 0, TRIXEL_LIGHT_PARAM_DIFFUSE, diffuse);
    trixel_light_param(t, 0, TRIXEL_LIGHT_PARAM_POSITION, position);

    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    
    //view
    glRotatef(pitch, -1.0, 0.0, 0.0);
    glRotatef(yaw, 0.0, 1.0, 0.0);
    glTranslatef(-eye[0], -eye[1], -eye[2]);

    trixel_draw_brick(g_brick);
    trixel_finish_draw(t);
    
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
benchmark(trixel_state t, float eye[], float yaw, float pitch)
{
    double start = timeofday();
    for(int i = 0; i < 200; ++i) {
        draw(t, eye, yaw, pitch);
        putchar('.'); fflush(stdout);
    }
    double bench = timeofday() - start;
    printf("\r%f seconds to draw 200 frames (%f fps)\n", bench, 200.0/bench);
}

static void
remake_shaders(trixel_state t)
{
    char * error;
    if(trixel_update_shaders(t, g_flags, &error)) {
        printf("Remade voxel program\n");
    } else {
        printf("Error trying to remake voxel program:\n%s\n", error);
        free(error);
    }
}

static void
main_loop(trixel_state t)
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

            case SDLK_c:
                printf("Toggling -X neighbor flag\n");
                g_brick->neighbor_flags ^= TRIXEL_NEIGHBOR_NEGX_FLAG;
                trixel_update_brick_textures(g_brick);
                break;
            case SDLK_r:
                printf("Toggling -Y neighbor flag\n");
                g_brick->neighbor_flags ^= TRIXEL_NEIGHBOR_NEGY_FLAG;
                trixel_update_brick_textures(g_brick);
                break;
            case SDLK_l:
                printf("Toggling -Z neighbor flag\n");
                g_brick->neighbor_flags ^= TRIXEL_NEIGHBOR_NEGZ_FLAG;
                trixel_update_brick_textures(g_brick);
                break;
            case SDLK_t:
                printf("Toggling +X neighbor flag\n");
                g_brick->neighbor_flags ^= TRIXEL_NEIGHBOR_POSX_FLAG;
                trixel_update_brick_textures(g_brick);
                break;
            case SDLK_n:
                printf("Toggling +Y neighbor flag\n");
                g_brick->neighbor_flags ^= TRIXEL_NEIGHBOR_POSY_FLAG;
                trixel_update_brick_textures(g_brick);
                break;
            case SDLK_s:
                printf("Toggling +Z neighbor flag\n");
                g_brick->neighbor_flags ^= TRIXEL_NEIGHBOR_POSZ_FLAG;
                trixel_update_brick_textures(g_brick);
                break;

            case SDLK_q:
                return;
            case SDLK_z:
                remake_shaders(t);
                break;
            case SDLK_b:
                benchmark(t, eye, yaw, pitch);
                break;
            case SDLK_3:
                printf("Toggling lighting\n");
                g_flags ^= TRIXEL_LIGHTING;
                remake_shaders(t);
                break;
            case SDLK_4:
                printf("Toggling smooth shading\n");
                g_flags ^= TRIXEL_SMOOTH_SHADING;
                remake_shaders(t);
                break;
            case SDLK_5:
                printf("Toggling exact depth\n");
                g_flags ^= TRIXEL_EXACT_DEPTH;
                remake_shaders(t);
                break;
            case SDLK_SPACE:
                eye[0] = 0.0; eye[1] = 0.0; eye[2] = 128.0;
                yaw = 0.0;
                pitch = 0.0;
                break;
            }
            break;
        }
        draw(t, eye, yaw, pitch);
    }
}

int
main(int argc, char * * argv)
{
    char *error_message;
    
    if(argc < 2) {
        asprintf(&error_message, "Usage: %s foo.brick", argv[0]);
        goto error;
    }
    
    SDL_Init(SDL_INIT_EVERYTHING);
    atexit(SDL_Quit);
    
    trixel_state t = set_video_mode(1024, 768, &error_message);
    if(!t)
        goto error;
    
    g_brick = trixel_read_brick_from_filename(argv[1], &error_message);
    if(!g_brick)
        goto error_after_init;
    trixel_prepare_brick(g_brick, t);
    
    main_loop(t);
    
    trixel_finish(t);
    
    return 0;

error_after_init:
    trixel_finish(t);
error:
    fprintf(stderr, "%s\n", error_message);
    free(error_message);
    return 1;
}
