#import "MasonBrickView.h"
#import "MasonDocument.h"
#import "MasonApplication.h"
#import "MasonToolboxController.h"
#import "MasonTool.h"
#include <GL/glew.h>
#include <math.h>

#include "trixel.h"

#define MOUSE_ROTATE_FACTOR 1.0
#define MOUSE_DISTANCE_FACTOR 1.0

#define INITIAL_DISTANCE 32.0

const size_t g_num_draw_buffers = 3;
const GLenum g_tool_inactive_draw_buffers[] = { GL_COLOR_ATTACHMENT0_EXT, GL_COLOR_ATTACHMENT1_EXT, GL_COLOR_ATTACHMENT2_EXT };
const GLenum g_tool_active_draw_buffers[]   = { GL_COLOR_ATTACHMENT0_EXT, GL_NONE,                  GL_NONE                  };

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

- (BOOL)acceptsFirstMouse:(NSEvent *)event
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
    m_toolActive = NO;
    
    NSOpenGLPixelFormat * pf = [[NSOpenGLPixelFormat alloc] initWithAttributes:pfa];
    if(!pf) {
        return;
    }
    [self setPixelFormat:pf];
    [pf release];
    
    [[self window] setAcceptsMouseMovedEvents:YES];
    m_trackingRect = [self addTrackingRect:[self bounds] owner:self userData:nil assumeInside:YES];
    
    [[NSApp toolboxController] addObserver:self forKeyPath:@"currentTool" options:NSKeyValueObservingOptionNew context:NULL];
    
    [[self window] invalidateCursorRectsForView:self];
}

- (void)dealloc
{
    [[NSApp toolboxController] removeObserver:self forKeyPath:@"currentTool"];
    
    if(m_t) {
        glDeleteFramebuffersEXT(1, &m_framebuffer);
        glDeleteTextures(1, &m_color_texture);
        glDeleteRenderbuffersEXT(1, &m_hover_renderbuffer);
        glDeleteRenderbuffersEXT(1, &m_depth_renderbuffer);
        glDeleteRenderbuffersEXT(1, &m_normal_renderbuffer);
        
        trixel_finish(m_t);
    }

    [super dealloc];
}

- (void)observeValueForKeyPath:(NSString*)path ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if(object == [NSApp toolboxController] && [path isEqualToString:@"currentTool"]) {
        [[self window] invalidateCursorRectsForView:self];
    }
    //[super observeValueForKeyPath:path ofObject:object change:change context:context];
}

- (void)resetCursorRects
{
    if(m_toolActive)
        [self addCursorRect:[self bounds] cursor:[[[NSApp toolboxController] currentTool] activeCursor]];
    else
        [self addCursorRect:[self bounds] cursor:[[[NSApp toolboxController] currentTool] inactiveCursor]];
}

- (void)prepareOpenGL
{
    NSLog(@"context %@", [self openGLContext]);
    
    char *shader_flags[] = {
        TRIXEL_SAVE_COORDINATES,
        NULL
    };
    [super prepareOpenGL];
    char *error_message;
    NSRect frame = [self bounds];
    m_t = trixel_init_opengl(
        [[[NSBundle mainBundle] resourcePath] UTF8String],
        NSWidth(frame), NSHeight(frame),
        (char const * *)shader_flags,
        &error_message
    );
    
    if(!m_t) {
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

    glGenRenderbuffersEXT(1, &m_hover_renderbuffer);
    glGenRenderbuffersEXT(1, &m_depth_renderbuffer);
    glGenRenderbuffersEXT(1, &m_normal_renderbuffer);
    
    [self _reshape_framebuffer];
    
    glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_RECTANGLE_ARB, m_color_texture, 0);
    glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT1_EXT, GL_RENDERBUFFER_EXT, m_hover_renderbuffer);
    glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT2_EXT, GL_RENDERBUFFER_EXT, m_normal_renderbuffer);
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
    if(!m_t)
        return;

    NSRect frame = [self bounds];
    
    [self removeTrackingRect:m_trackingRect];
    m_trackingRect = [self addTrackingRect:frame owner:self userData:nil assumeInside:NO];
    [[self window] invalidateCursorRectsForView:self];
    
    trixel_reshape(m_t, NSWidth(frame), NSHeight(frame));
    
    [self _reshape_framebuffer];
    
    [[self openGLContext] update];
    [self setNeedsDisplay:YES];
}

- (void)yaw:(float)yoffset pitch:(float)poffset
{
    m_yaw = m_yaw + yoffset * MOUSE_ROTATE_FACTOR;
    m_pitch = fbound(m_pitch + poffset * MOUSE_ROTATE_FACTOR, -90.0, 90.0);
}

- (void)_reshape_framebuffer
{
    NSRect frame = [self bounds];
    
    glBindTexture(GL_TEXTURE_RECTANGLE_ARB, m_color_texture);
    glTexImage2D(GL_TEXTURE_RECTANGLE_ARB, 0, GL_RGBA16F_ARB, NSWidth(frame), NSHeight(frame), 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);

    glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, m_hover_renderbuffer);
    glRenderbufferStorageEXT(GL_RENDERBUFFER_EXT, GL_RGBA16F_ARB, NSWidth(frame), NSHeight(frame));

    glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, m_normal_renderbuffer);
    glRenderbufferStorageEXT(GL_RENDERBUFFER_EXT, GL_RGBA16F_ARB, NSWidth(frame), NSHeight(frame));

    glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, m_depth_renderbuffer);
    glRenderbufferStorageEXT(GL_RENDERBUFFER_EXT, GL_DEPTH_COMPONENT32, NSWidth(frame), NSHeight(frame));
}

- (void)drawRect:(NSRect)r
{
    const GLenum *draw_buffers = (m_toolActive ? g_tool_active_draw_buffers : g_tool_inactive_draw_buffers);
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, m_framebuffer);
    
    glDrawBuffersARB(g_num_draw_buffers - 1, draw_buffers + 1);
    glClearColor(0.0, 0.0, 0.0, 0.0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glDrawBuffer(draw_buffers[0]);
    glClearColor(0.2, 0.2, 0.2, 1.0);    
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glDrawBuffersARB(g_num_draw_buffers, draw_buffers);
    
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    glTranslatef(0.0, 0.0, -m_distance);
    glRotatef(m_pitch, 1.0, 0.0, 0.0);
    glRotatef(m_yaw,   0.0, 1.0, 0.0);
    
    trixel_draw_brick(m_t, [o_document brick]);
    
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
    [self mouseMoved:event];

    [[[NSApp toolboxController] currentTool]
        handleMouseDraggedFrom:[self convertPoint:[event locationInWindow] fromView:nil]
        delta:NSMakePoint([event deltaX], [event deltaY])
        forDocument:o_document];
    
    [self setNeedsDisplay:YES];
}

- (void)mouseDown:(NSEvent *)event
{
    m_toolActive = YES;
    [[self window] invalidateCursorRectsForView:self];
    
    [[[NSApp toolboxController] currentTool]
        handleMouseDraggedFrom:[self convertPoint:[event locationInWindow] fromView:nil]
        delta:NSMakePoint(0, 0)
        forDocument:o_document];    

    [self mouseMoved:event];
    [self setNeedsDisplay:YES];
}

- (void)mouseUp:(NSEvent *)event
{
    m_toolActive = NO;
    [[self window] invalidateCursorRectsForView:self];    
    [self setNeedsDisplay:YES];
}

- (void)scrollWheel:(NSEvent *)event
{
    m_distance = fmax(m_distance - [event deltaY], 0.0);
    
    [self setNeedsDisplay:YES];
}

- (void)mouseEntered:(NSEvent *)event
{
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
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);
    
    if(hoverPixelColor[3] == 0.0)
        return (struct point3){ -1, -1, -1 };
    else
        return (struct point3){
            hoverPixelColor[0],
            hoverPixelColor[1],
            hoverPixelColor[2]
        };
}

- (NSString*)hoverPointString
{
    struct point3 hoverPoint = [self hoverPoint];
    if(hoverPoint.x != -1.0)
        return [NSString stringWithFormat:@"(%.0f, %.0f, %.0f)", hoverPoint.x, hoverPoint.y, hoverPoint.z];
    else
        return @"";
}

@end
