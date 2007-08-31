#import "MasonBrickView.h"
#import "MasonDocument.h"
#include <GL/glew.h>
#include <math.h>

#include "trixel.h"

#define MOUSE_ROTATE_FACTOR 1.0
#define MOUSE_DISTANCE_FACTOR 1.0

#define INITIAL_DISTANCE 32.0

const GLenum g_draw_buffers[] = { GL_COLOR_ATTACHMENT0_EXT, GL_COLOR_ATTACHMENT1_EXT };
const size_t g_num_draw_buffers = 2;

float
fbound(float x, float mn, float mx)
{
    return fmin(fmax(x, mn), mx);
}

@implementation MasonBrickView

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
    if([key isEqualToString:@"hoverPoint"])
        return NO;
    else
        return [super automaticallyNotifiesObserversForKey:key];
}

+ (void)initialize
{
    [self setKeys:[NSArray arrayWithObject:@"hoverPoint"]
          triggerChangeNotificationsForDependentKey:@"hoverPointString"];
}

- (BOOL)isOpaque
{
    return YES;
}

- (BOOL)acceptsFirstResponder
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
    m_hovering = NO;
    
    NSOpenGLPixelFormat * pf = [[NSOpenGLPixelFormat alloc] initWithAttributes:pfa];
    if(!pf) {
        return;
    }
    [self setPixelFormat:pf];
    [pf release];
    
    [[self window] setAcceptsMouseMovedEvents:YES];
    m_trackingRect = [self addTrackingRect:[self bounds] owner:self userData:nil assumeInside:YES];
}

- (void)prepareOpenGL
{
    char *shader_flags[] = {
        TRIXEL_SAVE_COORDINATES,
        NULL
    };
    [super prepareOpenGL];
    char *error_message;
    NSRect frame = [self bounds];
    m_initialized = trixel_init_opengl(
        [[[NSBundle mainBundle] resourcePath] UTF8String],
        NSWidth(frame), NSHeight(frame),
        (char const * *)shader_flags,
        &error_message
    );
    
    if(!m_initialized) {
        NSLog(@"%s", error_message); // xxx proper error handling
        return;
    }
    
    glEnable(GL_TEXTURE_RECTANGLE_ARB);
    
    glGenFramebuffersEXT(1, &m_framebuffer);
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, m_framebuffer);
    
    glGenTextures(1, &m_color_texture);
    glBindTexture(GL_TEXTURE_RECTANGLE_ARB, m_color_texture);
    glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_S, GL_CLAMP);
    glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_T, GL_CLAMP);
    glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_R, GL_CLAMP);

    glGenTextures(1, &m_hover_texture);
    glBindTexture(GL_TEXTURE_RECTANGLE_ARB, m_hover_texture);
    glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_S, GL_CLAMP);
    glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_T, GL_CLAMP);
    glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_R, GL_CLAMP);

    glGenRenderbuffersEXT(1, &m_depth_renderbuffer);
    
    [self _reshape_framebuffer];
    
    glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_RECTANGLE_ARB, m_color_texture, 0);
    glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT1_EXT, GL_TEXTURE_RECTANGLE_ARB, m_hover_texture, 0);
    glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_DEPTH_ATTACHMENT_EXT,  GL_RENDERBUFFER_EXT, m_depth_renderbuffer);

    if(glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT) != GL_FRAMEBUFFER_COMPLETE_EXT)
    {
        NSLog(@"framebuffer not complete %d", glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT));
    }
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);

    trixel_prepare_brick([o_document brick]);
}

- (void)reshape
{
    if(!m_initialized)
        return;

    NSRect frame = [self bounds];
    
    [self removeTrackingRect:m_trackingRect];
    m_trackingRect = [self addTrackingRect:frame owner:self userData:nil assumeInside:NO];
    
    trixel_reshape(NSWidth(frame), NSHeight(frame));
    
    [self _reshape_framebuffer];
    
    [[self openGLContext] update];
    [self setNeedsDisplay:YES];
}

- (void)_reshape_framebuffer
{
    NSRect frame = [self bounds];
    
    glBindTexture(GL_TEXTURE_RECTANGLE_ARB, m_color_texture);
    glTexImage2D(GL_TEXTURE_RECTANGLE_ARB, 0, GL_RGBA32F_ARB, NSWidth(frame), NSHeight(frame), 0, GL_RGBA, GL_FLOAT, NULL);

    glBindTexture(GL_TEXTURE_RECTANGLE_ARB, m_hover_texture);
    glTexImage2D(GL_TEXTURE_RECTANGLE_ARB, 0, GL_RGBA32F_ARB, NSWidth(frame), NSHeight(frame), 0, GL_RGBA, GL_FLOAT, NULL);

    glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, m_depth_renderbuffer);
    glRenderbufferStorageEXT(GL_RENDERBUFFER_EXT, GL_DEPTH_COMPONENT32, NSWidth(frame), NSHeight(frame));

}

- (void)drawRect:(NSRect)r
{
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, m_framebuffer);
    
    glDrawBuffer(GL_COLOR_ATTACHMENT1_EXT);
    glClearColor(1.0, 1.0, 1.0, 0.0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glDrawBuffer(GL_COLOR_ATTACHMENT0_EXT);
    glClearColor(0.2, 0.2, 0.2, 1.0);    
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glDrawBuffersARB(g_num_draw_buffers, g_draw_buffers);
    
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    glTranslatef(0.0, 0.0, -m_distance);
    glRotatef(m_pitch, 1.0, 0.0, 0.0);
    glRotatef(m_yaw,   0.0, 1.0, 0.0);
    
    trixel_draw_brick([o_document brick]);
    
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);
    glDrawBuffer(GL_BACK);
    glMatrixMode(GL_PROJECTION);
    glPushMatrix();
    glLoadIdentity();
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    
    NSRect frame = [self bounds];
    glUseProgramObjectARB(0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glBindTexture(GL_TEXTURE_RECTANGLE_ARB, m_color_texture);
    glBegin(GL_QUADS);
    glTexCoord2f(0.0, 0.0);
    glVertex2f(-1.0, -1.0);
    glTexCoord2f(NSWidth(frame), 0.0);
    glVertex2f(1.0, -1.0);
    glTexCoord2f(NSWidth(frame), NSHeight(frame));
    glVertex2f(1.0, 1.0);
    glTexCoord2f(0.0, NSHeight(frame));
    glVertex2f(-1.0, 1.0);
    glEnd();
    
    glMatrixMode(GL_PROJECTION);
    glPopMatrix();
    
    [[self openGLContext] flushBuffer];
}

- (void)mouseDragged:(NSEvent *)event
{
    m_yaw = m_yaw + [event deltaX] * MOUSE_ROTATE_FACTOR;
    m_pitch = fbound(m_pitch + [event deltaY] * MOUSE_ROTATE_FACTOR, -90.0, 90.0);
    
    [self mouseMoved:event];
    [self setNeedsDisplay:YES];
}

- (void)scrollWheel:(NSEvent *)event
{
    m_distance = fmax(m_distance - [event deltaY], 0.0);
    
    [self setNeedsDisplay:YES];
}

- (void)mouseEntered:(NSEvent *)event
{
    NSLog(@"mouseentered");
    [self willChangeValueForKey:@"hoverPoint"];
    m_hovering = YES;
    [self didChangeValueForKey:@"hoverPoint"];
}

- (void)mouseMoved:(NSEvent *)event
{
    if(!m_hovering)
        return;
    [self willChangeValueForKey:@"hoverPoint"];
    m_hoverPixel = [self convertPoint:[event locationInWindow] fromView:nil];
    [self didChangeValueForKey:@"hoverPoint"];
}

- (void)mouseExited:(NSEvent *)event
{
    NSLog(@"mouseexited");
    [self willChangeValueForKey:@"hoverPoint"];
    m_hovering = NO;
    [self didChangeValueForKey:@"hoverPoint"];
}

- (struct point3)hoverPoint
{
    if(!m_hovering)
        return (struct point3){ -1, -1, -1 };

    float hoverPixelColor[4];
    
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, m_framebuffer);
    glReadBuffer(GL_COLOR_ATTACHMENT1_EXT);
    glReadPixels(
        (GLint)m_hoverPixel.x, (GLint)m_hoverPixel.y,
        1, 1,
        GL_RGBA,
        GL_FLOAT,
        hoverPixelColor
    );
    
    if(hoverPixelColor[3] == 0.0)
        return (struct point3){ -1, -1, -1 };
    else
        return (struct point3){
            hoverPixelColor[0],
            hoverPixelColor[1],
            hoverPixelColor[2]
        };
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);
}

- (NSString*)hoverPointString
{
    struct point3 hoverPoint = [self hoverPoint];
    if(hoverPoint.x != -1.0)
        return [NSString stringWithFormat:@"(%.3f, %.3f, %.3f)", hoverPoint.x, hoverPoint.y, hoverPoint.z];
    else
        return @"";
}

@end
