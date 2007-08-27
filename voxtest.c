#include <SDL.h>
#include <GL/glew.h>
#include <sys/time.h>

#include "trixel.h"

static trixel_brick * g_brick;

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

    if(!trixel_init_opengl(".", width, height, out_error_message))
        goto error;

    return screen;

error_from_sdl:
    *out_error_message = strdup(SDL_GetError());
error:
    return NULL;
}

static void
draw(float eye[], float yaw, float pitch)
{
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    //view
    glRotatef(pitch, -1.0, 0.0, 0.0);
    glRotatef(yaw, 0.0, 1.0, 0.0);
    glTranslatef(-eye[0], -eye[1], -eye[2]);

    trixel_draw_brick(g_brick);
    
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
                {
                    char * error;
                    if(trixel_update_shaders(&error)) {
                        printf("Remade voxel program\n");
                    } else {
                        printf("Error trying to remake voxel program:\n%s\n", error);
                        free(error);
                    }
                }
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
main(int argc, char * * argv)
{
    char *error_message;
    
    if(argc < 2) {
        asprintf(&error_message, "Usage: %s foo.brick", argv[0]);
        goto error;
    }
    
    SDL_Init(SDL_INIT_EVERYTHING);
    atexit(SDL_Quit);
    
    if(!set_video_mode(1024, 768, &error_message))
        goto error;
    
    g_brick = trixel_read_brick_from_filename(argv[1], true, &error_message);
    if(!g_brick)
        goto error_after_init;
    
    main_loop();
    
    trixel_finish();
    
    return 0;

error_after_init:
    trixel_finish();
error:
    fprintf(stderr, "%s\n", error_message);
    free(error_message);
    return 1;
}
