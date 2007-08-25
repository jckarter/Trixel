#import "MasonBrickView.h"
#include <GL/glew.h>
#include <math.h>

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
    [self reshape];
    glClearColor(0.2, 0.2, 0.2, 1.0);
}

- (void)reshape
{
    NSRect frame = [self bounds];
    float fovratio = fmin(NSWidth(frame), NSHeight(frame)),
          fovx = NSWidth(frame)/fovratio,
          fovy = NSHeight(frame)/fovratio;
    
    glViewport(0, 0, NSWidth(frame), NSHeight(frame));
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glFrustum(-4.0 * fovx, 4.0 * fovx, -4.0 * fovy, 4.0 * fovy, 4.0, 512.0);
    
    [[self openGLContext] update];
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)r
{
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glBegin(GL_QUADS);
    glVertex3f(-32.0, -32.0, -64.0);
    glVertex3f( 32.0, -32.0, -64.0);
    glVertex3f( 32.0,  32.0, -64.0);
    glVertex3f(-32.0,  32.0, -64.0);
    glEnd();
    
    [[self openGLContext] flushBuffer];
}

@end
