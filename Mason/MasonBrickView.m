#import "MasonBrickView.h"
#import "MasonDocument.h"
#include <GL/glew.h>
#include <math.h>

#include "trixel.h"

#define MOUSE_ROTATE_FACTOR 1.0
#define MOUSE_DISTANCE_FACTOR 1.0

#define INITIAL_DISTANCE 32.0

@implementation MasonBrickView

- (BOOL)isOpaque
{
    return YES;
}

- (void)awakeFromNib
{
    NSOpenGLPixelFormatAttribute pfa[] = {
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFADepthSize, 32,
        0
    };
    
    m_yaw = m_pitch = 0.0;
    m_distance = INITIAL_DISTANCE;
    
    NSOpenGLPixelFormat * pf = [[NSOpenGLPixelFormat alloc] initWithAttributes:pfa];
    if(!pf) {
        return;
    }
    [self setPixelFormat:pf];
    [pf release];
}

- (void)prepareOpenGL
{
    [super prepareOpenGL];
    char *error_message;
    NSRect frame = [self bounds];
    BOOL didInitialize = trixel_init_opengl(
        [[[NSBundle mainBundle] resourcePath] UTF8String],
        NSWidth(frame), NSHeight(frame),
        &error_message
    );
    
    if(!didInitialize) {
        NSLog(@"%s", error_message); // xxx proper error handling
        return;
    }
    trixel_brick_prepare([o_document brick]);
}

- (void)reshape
{
    NSRect frame = [self bounds];
    
    trixel_reshape(NSWidth(frame), NSHeight(frame));
    
    [[self openGLContext] update];
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)r
{
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    glTranslatef(0.0, 0.0, -m_distance);
    glRotatef(m_pitch, 1.0, 0.0, 0.0);
    glRotatef(m_yaw,   0.0, 1.0, 0.0);
    
    trixel_draw_brick([o_document brick]);
    
    [[self openGLContext] flushBuffer];
}

- (void)mouseDragged:(NSEvent *)event
{
    m_yaw += [event deltaX] * MOUSE_ROTATE_FACTOR;
    m_pitch += [event deltaY] * MOUSE_ROTATE_FACTOR;
    
    [self setNeedsDisplay:YES];
}

- (void)scrollWheel:(NSEvent *)event
{
    m_distance += [event deltaY];
    
    [self setNeedsDisplay:YES];
}

@end
