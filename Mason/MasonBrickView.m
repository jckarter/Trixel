#import "MasonBrickView.h"
#import "MasonDocument.h"
#import "MasonApplication.h"
#import "MasonToolboxController.h"
#import "MasonTool.h"
#import "MasonBrick.h"
#include <GL/glew.h>
#include <math.h>

#include "trixel.h"

#define MOUSE_ROTATE_FACTOR 1.0
#define MOUSE_DISTANCE_FACTOR 1.0

#define INITIAL_DISTANCE 32.0

static const size_t g_num_draw_buffers = 3;
static const GLenum g_tool_inactive_draw_buffers[] = { GL_COLOR_ATTACHMENT0_EXT, GL_COLOR_ATTACHMENT1_EXT, GL_COLOR_ATTACHMENT2_EXT };
static const GLenum g_tool_active_draw_buffers[]   = { GL_COLOR_ATTACHMENT0_EXT, GL_NONE,                  GL_NONE                  };

static const char * g_surface_flags[] = { TRIXEL_SAVE_COORDINATES, NULL };
static const char * g_slice_flags[] = { TRIXEL_SAVE_COORDINATES, TRIXEL_SURFACE_ONLY, NULL };
static const GLshort g_surface_elements[] = {
    0, 1, 2, 3,
    0, 4, 5, 1,
    4, 7, 6, 5,
    3, 2, 6, 7,
    0, 3, 7, 4,
    2, 1, 5, 6
};

float
fbound(float x, float mn, float mx)
{
    return fmin(fmax(x, mn), mx);
}

void
surface_set_up_state(void)
{
    glDisable(GL_BLEND);
}

void
slice_set_up_state(void)
{
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_BLEND);
}

@interface MasonBrickView ()
- (void)_drawBrick:(MasonBrick *)brick sliceAxis:(NSInteger)axis sliceNumber:(NSInteger)sliceNumber;
- (void)_drawFramebufferToWindow;

- (void)_generateFramebuffer;
- (void)_prepareVertexBufferForBrick:(MasonBrick *)brick;
- (void)_destroyFramebuffer;

- (struct point3)_hoverValueFromBuffer:(GLenum)buffer;
@end

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

    m_framebuffer = m_color_texture = m_hover_renderbuffer = m_depth_renderbuffer = 0;
    
    m_yaw = m_pitch = 0.0;
    m_distance = INITIAL_DISTANCE;
    m_hovering = NO;
    m_toolActive = NO;
    
    NSOpenGLPixelFormat * pf = [[NSOpenGLPixelFormat alloc] initWithAttributes:pfa];
    if(!pf) {
        return;
    }
    [self setPixelFormat:pf];
    
    [[self window] setAcceptsMouseMovedEvents:YES];
    [self addTrackingArea:[[NSTrackingArea alloc]
            initWithRect:[self bounds]
            options:NSTrackingMouseEnteredAndExited
                | NSTrackingMouseMoved
                | NSTrackingActiveInKeyWindow
                | NSTrackingInVisibleRect
            owner:self
            userInfo:nil]];
    
    [[NSApp toolboxController] addObserver:self forKeyPath:@"currentTool" options:NSKeyValueObservingOptionOld context:NULL];
    [[NSApp toolboxController] addObserver:self forKeyPath:@"showBoundingBox" options:NSKeyValueObservingOptionOld context:NULL];
    [[NSApp toolboxController] addObserver:self forKeyPath:@"showAxes" options:NSKeyValueObservingOptionOld context:NULL];
    [o_document addObserver:self forKeyPath:@"sliceAxis" options:NSKeyValueObservingOptionOld context:NULL];
    [o_document addObserver:self forKeyPath:@"sliceNumber" options:NSKeyValueObservingOptionOld context:NULL];
    [o_document addObserver:self forKeyPath:@"brick" options:NSKeyValueObservingOptionOld context:NULL];
    [[o_document brick] addObserver:self forKeyPath:@"voxmap" options:NSKeyValueObservingOptionOld context:NULL];
    [[o_document brick] addObserver:self forKeyPath:@"paletteColors" options:NSKeyValueObservingOptionOld context:NULL];
    
    [[self window] invalidateCursorRectsForView:self];
}

- (void)finalize
{
    trixel_only_free(m_t);
    [super finalize];
}

- (void)observeValueForKeyPath:(NSString*)path ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if(object == [NSApp toolboxController] && [path isEqualToString:@"currentTool"]) {
        [[self window] invalidateCursorRectsForView:self];
    }
    else if(object == [NSApp toolboxController]
            && ([path isEqualToString:@"showBoundingBox"] || [path isEqualToString:@"showAxes"])) {
        [self setNeedsDisplay:YES];
    }
    else if(object == o_document && [path isEqualToString:@"sliceAxis"] && m_t) {
        char * error;
        if(!trixel_update_shaders(
            m_t,
            m_slice_ops[ [o_document sliceAxis] ].trixel_flags,
            &error
        )) {
            NSLog(@"error resetting trixel flags!! %s", error); // XXX real error handling
            free(error);
        }
        m_slice_ops[ [o_document sliceAxis] ].set_up_state_func();
        
        [self setNeedsDisplay:YES];
    }
    else if(object == o_document && [path isEqualToString:@"brick"]) {
        [[change objectForKey:NSKeyValueChangeOldKey] removeObserver:self forKeyPath:@"voxmap"];
        [[change objectForKey:NSKeyValueChangeOldKey] removeObserver:self forKeyPath:@"paletteColors"];
        [o_document.brick addObserver:self forKeyPath:@"voxmap" options:NSKeyValueObservingOptionOld context:NULL];
        [o_document.brick addObserver:self forKeyPath:@"paletteColors" options:NSKeyValueObservingOptionOld context:NULL];

        [self _prepareVertexBufferForBrick:o_document.brick];
        [o_document.brick prepare];
        [self setNeedsDisplay:YES];
    }
    else if((object == o_document && [path isEqualToString:@"sliceNumber"])
            || object == [o_document brick])
        [self setNeedsDisplay:YES];
    //[super observeValueForKeyPath:path ofObject:object change:change context:context];
}

- (void)resetCursorRects
{
    if(m_toolActive)
        [self addCursorRect:[self bounds] cursor:[[[NSApp toolboxController] currentTool] activeCursor]];
    else
        [self addCursorRect:[self bounds] cursor:[[[NSApp toolboxController] currentTool] inactiveCursor]];
}

- (void)_prepareVertexBufferForBrick:(MasonBrick *)brick
{
    int width = brick.width, height = brick.height, depth = brick.depth;
        
    int width_elt_offset = 24,
        height_elt_offset = width_elt_offset + width * 8,
        depth_elt_offset = height_elt_offset + height * 8;
    
    int width_offset = width_elt_offset * 3,
        height_offset = height_elt_offset * 3,
        depth_offset = depth_elt_offset * 3;
    size_t vertex_count = (24 + (width + height + depth) * 8) * 12;
    
    GLbyte buffer[vertex_count * (sizeof(GLfloat) + sizeof(GLbyte))];

    m_normals_offset = vertex_count * sizeof(GLfloat);
    
    GLfloat * vertices = (GLfloat *)buffer;
    GLbyte  * normals  = buffer + m_normals_offset;
    
    vertices[ 0] = -width/2; vertices[ 1] = -height/2; vertices[ 2] = -depth/2;
    vertices[ 3] = -width/2; vertices[ 4] =  height/2; vertices[ 5] = -depth/2;
    vertices[ 6] =  width/2; vertices[ 7] =  height/2; vertices[ 8] = -depth/2;
    vertices[ 9] =  width/2; vertices[10] = -height/2; vertices[11] = -depth/2;
        
    vertices[12] =  width/2; vertices[13] = -height/2; vertices[14] = -depth/2;
    vertices[15] =  width/2; vertices[16] =  height/2; vertices[17] = -depth/2;
    vertices[18] =  width/2; vertices[19] =  height/2; vertices[20] =  depth/2;
    vertices[21] =  width/2; vertices[22] = -height/2; vertices[23] =  depth/2;
        
    vertices[24] =  width/2; vertices[25] = -height/2; vertices[26] =  depth/2;
    vertices[27] =  width/2; vertices[28] =  height/2; vertices[29] =  depth/2;
    vertices[30] = -width/2; vertices[31] =  height/2; vertices[32] =  depth/2;
    vertices[33] = -width/2; vertices[34] = -height/2; vertices[35] =  depth/2;
        
    vertices[36] = -width/2; vertices[37] = -height/2; vertices[38] =  depth/2;
    vertices[39] = -width/2; vertices[40] =  height/2; vertices[41] =  depth/2;
    vertices[42] = -width/2; vertices[43] =  height/2; vertices[44] = -depth/2;
    vertices[45] = -width/2; vertices[46] = -height/2; vertices[47] = -depth/2;

    vertices[48] =  width/2; vertices[49] =  height/2; vertices[50] =  depth/2;
    vertices[51] =  width/2; vertices[52] =  height/2; vertices[53] = -depth/2;
    vertices[54] = -width/2; vertices[55] =  height/2; vertices[56] = -depth/2;
    vertices[57] = -width/2; vertices[58] =  height/2; vertices[59] =  depth/2;

    vertices[60] = -width/2; vertices[61] = -height/2; vertices[62] =  depth/2;
    vertices[63] = -width/2; vertices[64] = -height/2; vertices[65] = -depth/2;
    vertices[66] =  width/2; vertices[67] = -height/2; vertices[68] = -depth/2;
    vertices[69] =  width/2; vertices[70] = -height/2; vertices[71] =  depth/2;

    normals[ 0] = 0; normals[ 1] = 0; normals[ 2] = -128;
    normals[ 3] = 0; normals[ 4] = 0; normals[ 5] = -128;
    normals[ 6] = 0; normals[ 7] = 0; normals[ 8] = -128;
    normals[ 9] = 0; normals[10] = 0; normals[11] = -128;
        
    normals[12] = 127; normals[13] = 0; normals[14] = 0;
    normals[15] = 127; normals[16] = 0; normals[17] = 0;
    normals[18] = 127; normals[19] = 0; normals[20] = 0;
    normals[21] = 127; normals[22] = 0; normals[23] = 0;
        
    normals[24] = 0; normals[25] = 0; normals[26] = 127;
    normals[27] = 0; normals[28] = 0; normals[29] = 127;
    normals[30] = 0; normals[31] = 0; normals[32] = 127;
    normals[33] = 0; normals[34] = 0; normals[35] = 127;
        
    normals[36] = -128; normals[37] = 0; normals[38] = 0;
    normals[39] = -128; normals[40] = 0; normals[41] = 0;
    normals[42] = -128; normals[43] = 0; normals[44] = 0;
    normals[45] = -128; normals[46] = 0; normals[47] = 0;

    normals[48] = 0; normals[49] = 127; normals[50] = 0;
    normals[51] = 0; normals[52] = 127; normals[53] = 0;
    normals[54] = 0; normals[55] = 127; normals[56] = 0;
    normals[57] = 0; normals[58] = 127; normals[59] = 0;

    normals[60] = 0; normals[61] = -128; normals[62] = 0;
    normals[63] = 0; normals[64] = -128; normals[65] = 0;
    normals[66] = 0; normals[67] = -128; normals[68] = 0;
    normals[69] = 0; normals[70] = -128; normals[71] = 0;

    unsigned i;
    for(i = 0; i < width; ++i) {
        GLfloat w = (GLfloat)i + 0.5 - width/2;
        int base = width_offset + i * 8*3;

        vertices[base +  0] = vertices[base + 21] =  w;
        vertices[base +  1] = vertices[base + 22] = -height/2;
        vertices[base +  2] = vertices[base + 23] = -depth/2;
        
        vertices[base +  3] = vertices[base + 18] =  w;
        vertices[base +  4] = vertices[base + 19] =  height/2;
        vertices[base +  5] = vertices[base + 20] = -depth/2;
        
        vertices[base +  6] = vertices[base + 15] =  w;
        vertices[base +  7] = vertices[base + 16] =  height/2;
        vertices[base +  8] = vertices[base + 17] =  depth/2;
        
        vertices[base +  9] = vertices[base + 12] =  w;
        vertices[base + 10] = vertices[base + 13] = -height/2;
        vertices[base + 11] = vertices[base + 14] =  depth/2;
        
        normals[base +  0] = normals[base +  3] = normals[base +  6] = normals[base +  9] = 127;
        normals[base +  1] = normals[base +  4] = normals[base +  7] = normals[base + 10] =   0;
        normals[base +  2] = normals[base +  5] = normals[base +  8] = normals[base + 11] =   0;

        normals[base + 12] = normals[base + 15] = normals[base + 18] = normals[base + 21] = -128;
        normals[base + 13] = normals[base + 16] = normals[base + 19] = normals[base + 22] =    0;
        normals[base + 14] = normals[base + 17] = normals[base + 20] = normals[base + 23] =    0;
    }
    for(i = 0; i < height; ++i) {
        GLfloat h = (GLfloat)i + 0.5 - height/2;
        int base = height_offset + i * 8*3;

        vertices[base +  0] = vertices[base + 21] = -width/2;
        vertices[base +  1] = vertices[base + 22] =  h;
        vertices[base +  2] = vertices[base + 23] = -depth/2;
        
        vertices[base +  3] = vertices[base + 18] = -width/2;
        vertices[base +  4] = vertices[base + 19] =  h;
        vertices[base +  5] = vertices[base + 20] =  depth/2;
        
        vertices[base +  6] = vertices[base + 15] =  width/2;
        vertices[base +  7] = vertices[base + 16] =  h;
        vertices[base +  8] = vertices[base + 17] =  depth/2;
        
        vertices[base +  9] = vertices[base + 12] =  width/2;
        vertices[base + 10] = vertices[base + 13] =  h;
        vertices[base + 11] = vertices[base + 14] = -depth/2;
        
        normals[base +  0] = normals[base +  3] = normals[base +  6] = normals[base +  9] =   0;
        normals[base +  1] = normals[base +  4] = normals[base +  7] = normals[base + 10] = 127;
        normals[base +  2] = normals[base +  5] = normals[base +  8] = normals[base + 11] =   0;

        normals[base + 12] = normals[base + 15] = normals[base + 18] = normals[base + 21] =    0;
        normals[base + 13] = normals[base + 16] = normals[base + 19] = normals[base + 22] = -128;
        normals[base + 14] = normals[base + 17] = normals[base + 20] = normals[base + 23] =    0;
    }
    for(i = 0; i < depth; ++i) {
        GLfloat d = (GLfloat)i + 0.5 - depth/2;
        int base = depth_offset + i * 8*3;

        vertices[base +  0] = vertices[base + 21] =  width/2;
        vertices[base +  1] = vertices[base + 22] = -height/2;
        vertices[base +  2] = vertices[base + 23] =  d;
        
        vertices[base +  3] = vertices[base + 18] =  width/2;
        vertices[base +  4] = vertices[base + 19] =  height/2;
        vertices[base +  5] = vertices[base + 20] =  d;
        
        vertices[base +  6] = vertices[base + 15] = -width/2;
        vertices[base +  7] = vertices[base + 16] =  height/2;
        vertices[base +  8] = vertices[base + 17] =  d;
        
        vertices[base +  9] = vertices[base + 12] = -width/2;
        vertices[base + 10] = vertices[base + 13] = -height/2;
        vertices[base + 11] = vertices[base + 14] =  d;
        
        normals[base +  0] = normals[base +  3] = normals[base +  6] = normals[base +  9] =   0;
        normals[base +  1] = normals[base +  4] = normals[base +  7] = normals[base + 10] =   0;
        normals[base +  2] = normals[base +  5] = normals[base +  8] = normals[base + 11] = 127;

        normals[base + 12] = normals[base + 15] = normals[base + 18] = normals[base + 21] =    0;
        normals[base + 13] = normals[base + 16] = normals[base + 19] = normals[base + 22] =    0;
        normals[base + 14] = normals[base + 17] = normals[base + 20] = normals[base + 23] = -128;
    }
    
    glBindBuffer(GL_ARRAY_BUFFER, m_vertex_buffer);
    glBufferData(GL_ARRAY_BUFFER, vertex_count * (sizeof(GLfloat)+sizeof(GLbyte)), buffer, GL_STATIC_DRAW);

    m_slice_ops[SLICE_AXIS_SURFACE].trixel_flags = g_surface_flags;
    m_slice_ops[SLICE_AXIS_SURFACE].buffer_first = 0;
    m_slice_ops[SLICE_AXIS_SURFACE].buffer_count = 24;    
    m_slice_ops[SLICE_AXIS_SURFACE].set_up_state_func = surface_set_up_state;

    m_slice_ops[SLICE_AXIS_XAXIS].trixel_flags = g_slice_flags;
    m_slice_ops[SLICE_AXIS_XAXIS].buffer_first = width_elt_offset;
    m_slice_ops[SLICE_AXIS_XAXIS].buffer_count = 8;    
    m_slice_ops[SLICE_AXIS_XAXIS].set_up_state_func = slice_set_up_state;

    m_slice_ops[SLICE_AXIS_YAXIS].trixel_flags = g_slice_flags;
    m_slice_ops[SLICE_AXIS_YAXIS].buffer_first = height_elt_offset;
    m_slice_ops[SLICE_AXIS_YAXIS].buffer_count = 8;    
    m_slice_ops[SLICE_AXIS_YAXIS].set_up_state_func = slice_set_up_state;

    m_slice_ops[SLICE_AXIS_ZAXIS].trixel_flags = g_slice_flags;
    m_slice_ops[SLICE_AXIS_ZAXIS].buffer_first = depth_elt_offset;
    m_slice_ops[SLICE_AXIS_ZAXIS].buffer_count = 8;    
    m_slice_ops[SLICE_AXIS_ZAXIS].set_up_state_func = slice_set_up_state;

    glBindBuffer(GL_ARRAY_BUFFER, 0);
}

- (void)prepareOpenGL
{    
    [super prepareOpenGL];

    char *error_message;
    NSRect frame = [self bounds];
    m_t = trixel_init_opengl(
        [[[NSBundle mainBundle] resourcePath] UTF8String],
        NSWidth(frame), NSHeight(frame),
        (char const * *)g_surface_flags,
        &error_message
    );
    
    if(!m_t) {
        NSLog(@"%s", error_message); // xxx proper error handling
        return;
    }

    glGenBuffers(1, &m_vertex_buffer);    
    MasonBrick * brick = o_document.brick;

    [self _prepareVertexBufferForBrick:brick];
    [brick prepare];
    [self _generateFramebuffer];
}

- (void)reshape
{
    if(!m_t)
        return;

    NSRect frame = [self bounds];
    
    [[self window] invalidateCursorRectsForView:self];
    
    trixel_reshape(m_t, NSWidth(frame), NSHeight(frame));
        
    [[self openGLContext] update];
    [self _generateFramebuffer];
    [self setNeedsDisplay:YES];
}

- (void)yaw:(float)yoffset pitch:(float)poffset
{
    m_yaw = m_yaw + yoffset * MOUSE_ROTATE_FACTOR;
    m_pitch = fbound(m_pitch + poffset * MOUSE_ROTATE_FACTOR, -90.0, 90.0);
    [self setNeedsDisplay:YES];
}

- (void)_generateFramebuffer
{
    if(m_framebuffer)
        [self _destroyFramebuffer];

    glGenFramebuffersEXT(1, &m_framebuffer);
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, m_framebuffer);
    
    NSRect frame = [self bounds];
    
    glGenTextures(1, &m_color_texture);
    glBindTexture(GL_TEXTURE_2D, m_color_texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_R, GL_CLAMP);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA16F_ARB, NSWidth(frame), NSHeight(frame), 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);

    glGenRenderbuffersEXT(1, &m_hover_renderbuffer);
    glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, m_hover_renderbuffer);
    glRenderbufferStorageEXT(GL_RENDERBUFFER_EXT, GL_RGBA16F_ARB, NSWidth(frame), NSHeight(frame));

    glGenRenderbuffersEXT(1, &m_normal_renderbuffer);
    glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, m_normal_renderbuffer);
    glRenderbufferStorageEXT(GL_RENDERBUFFER_EXT, GL_RGBA16F_ARB, NSWidth(frame), NSHeight(frame));

    glGenRenderbuffersEXT(1, &m_depth_renderbuffer);
    glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, m_depth_renderbuffer);
    glRenderbufferStorageEXT(GL_RENDERBUFFER_EXT, GL_DEPTH_COMPONENT32, NSWidth(frame), NSHeight(frame));
    
    glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_2D, m_color_texture, 0);
    glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT1_EXT, GL_RENDERBUFFER_EXT, m_hover_renderbuffer);
    glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT2_EXT, GL_RENDERBUFFER_EXT, m_normal_renderbuffer);
    glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_DEPTH_ATTACHMENT_EXT,  GL_RENDERBUFFER_EXT, m_depth_renderbuffer);

    if(glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT) != GL_FRAMEBUFFER_COMPLETE_EXT)
    {
        NSLog(@"framebuffer not complete %d", glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT));
    }
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);
}

- (void)_destroyFramebuffer
{
    glDeleteFramebuffersEXT(1, &m_framebuffer);
    glDeleteTextures(1, &m_color_texture);
    glDeleteRenderbuffersEXT(1, &m_hover_renderbuffer);
    glDeleteRenderbuffersEXT(1, &m_normal_renderbuffer);
    glDeleteRenderbuffersEXT(1, &m_depth_renderbuffer);
    
    m_framebuffer = m_color_texture = m_hover_renderbuffer = m_depth_renderbuffer = 0;
}

- (void)_drawBrick:(MasonBrick *)brick sliceAxis:(NSInteger)axis sliceNumber:(NSInteger)sliceNumber
{
    [brick useForDrawing:m_t];

    GLint first = m_slice_ops[axis].buffer_first;
    GLsizei count = m_slice_ops[axis].buffer_count;

    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_NORMAL_ARRAY);

    glBindBuffer(GL_ARRAY_BUFFER, m_vertex_buffer);
    glVertexPointer(3, GL_FLOAT, 0, 0);
    glNormalPointer(GL_BYTE, 0, (void*)m_normals_offset);

    glDrawArrays(GL_QUADS, first + count * sliceNumber, count);
    
    glBindBuffer(GL_ARRAY_BUFFER, 0);
}

- (void)drawBoundingCubeForBrick:(MasonBrick *)brick
{
    float width2  = ((float)[brick width] ) / 2,
          height2 = ((float)[brick height]) / 2,
          depth2  = ((float)[brick depth] ) / 2;
    
    glUseProgram(0);
    glDisable(GL_TEXTURE_2D);
    
    glBegin(GL_LINES);

    glColor4f(0.5, 0.4, 0.4, 1.0);
    glVertex3f(-width2, -height2, -depth2);
    glVertex3f(-width2, -height2,  depth2);

    glVertex3f(-width2,  height2, -depth2);
    glVertex3f(-width2,  height2,  depth2);

    glVertex3f( width2,  height2, -depth2);
    glVertex3f( width2,  height2,  depth2);

    glVertex3f( width2, -height2, -depth2);
    glVertex3f( width2, -height2,  depth2);
    
    glColor4f(0.4, 0.5, 0.4, 1.0);
    glVertex3f(-width2, -height2, -depth2);
    glVertex3f(-width2,  height2, -depth2);

    glVertex3f( width2, -height2, -depth2);
    glVertex3f( width2,  height2, -depth2);

    glVertex3f( width2, -height2,  depth2);
    glVertex3f( width2,  height2,  depth2);

    glVertex3f(-width2, -height2,  depth2);
    glVertex3f(-width2,  height2,  depth2);

    glColor4f(0.4, 0.4, 0.5, 1.0);
    glVertex3f(-width2, -height2, -depth2);
    glVertex3f( width2, -height2, -depth2);

    glVertex3f(-width2,  height2, -depth2);
    glVertex3f( width2,  height2, -depth2);

    glVertex3f(-width2,  height2,  depth2);
    glVertex3f( width2,  height2,  depth2);

    glVertex3f(-width2, -height2,  depth2);
    glVertex3f( width2, -height2,  depth2);

    glEnd();
}

- (void)drawAxesForBrick:(MasonBrick *)brick
{
    float width2  = ((float)[brick width] ) / 2,
          height2 = ((float)[brick height]) / 2,
          depth2  = ((float)[brick depth] ) / 2;
    
    glUseProgram(0);
    glDisable(GL_TEXTURE_2D);
    
    glBegin(GL_LINES);

    glColor4f(0.7, 0.5, 0.5, 1.0);
    glVertex3f(0.0, 0.0, 0.0);
    glVertex3f(0.0, 0.0, depth2 + 2.0);

    glColor4f(0.5, 0.7, 0.5, 1.0);
    glVertex3f(0.0, 0.0, 0.0);
    glVertex3f(0.0, height2 + 2.0, 0.0);

    glColor4f(0.5, 0.5, 0.7, 1.0);
    glVertex3f(0.0, 0.0, 0.0);
    glVertex3f(width2 + 2.0, 0.0, 0.0);

    glEnd();
}

- (void)_drawFramebufferToWindow
{
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);
    glDrawBuffer(GL_BACK);
    glMatrixMode(GL_PROJECTION);
    glPushMatrix();
    glLoadIdentity();
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    
    glUseProgram(0);
    glClear(GL_COLOR_BUFFER_BIT);
    glDisable(GL_DEPTH_TEST);
    glActiveTexture(GL_TEXTURE0);
    glEnable(GL_TEXTURE_2D);
    glBindTexture(GL_TEXTURE_2D, m_color_texture);
    glBegin(GL_QUADS);
    glColor3f(1.0, 1.0, 1.0);
    glTexCoord2f(0.0, 0.0);
    glVertex2f(-1.0, -1.0);
    glTexCoord2f(1.0, 0.0);
    glVertex2f(1.0, -1.0);
    glTexCoord2f(1.0, 1.0);
    glVertex2f(1.0, 1.0);
    glTexCoord2f(0.0, 1.0);
    glVertex2f(-1.0, 1.0);
    glEnd();
    
    glEnable(GL_DEPTH_TEST);
    glMatrixMode(GL_PROJECTION);
    glPopMatrix();    
}

- (void)drawRect:(NSRect)r
{
    const GLenum *draw_buffers = (m_toolActive ? g_tool_active_draw_buffers : g_tool_inactive_draw_buffers);
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, m_framebuffer);

    glDrawBuffers(g_num_draw_buffers - 1, draw_buffers + 1);
    glClearColor(0.0, 0.0, 0.0, 0.0);
    glClear(GL_COLOR_BUFFER_BIT);

    glDrawBuffer(draw_buffers[0]);
    glClearColor(0.2, 0.2, 0.2, 1.0);    
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    glTranslatef(0.0, 0.0, -m_distance);
    glRotatef(m_pitch, 1.0, 0.0, 0.0);
    glRotatef(m_yaw,   0.0, 1.0, 0.0);

    if([[NSApp toolboxController] showBoundingBox])
        [self drawBoundingCubeForBrick:[o_document brick]];
    if([[NSApp toolboxController] showAxes])
        [self drawAxesForBrick:[o_document brick]];    

    glDrawBuffers(g_num_draw_buffers, draw_buffers);
    [self _drawBrick:[o_document brick] sliceAxis:[o_document sliceAxis] sliceNumber:[o_document sliceNumber]];
    
    [self _drawFramebufferToWindow];
    
    [[self openGLContext] flushBuffer];
}

- (void)mouseDragged:(NSEvent *)event
{
    [self mouseMoved:event];

    [[[NSApp toolboxController] currentTool]
        handleMouseDraggedFrom:[self convertPoint:[event locationInWindow] fromView:nil]
        delta:NSMakePoint([event deltaX], [event deltaY])
        forDocument:o_document];
}

- (void)mouseDown:(NSEvent *)event
{
    m_toolActive = YES;
    [[self window] invalidateCursorRectsForView:self];

    MasonTool * currentTool = [[NSApp toolboxController] currentTool];
    if([currentTool isDestructive]) {
        [[o_document undoManager] beginUndoGrouping];
    }
    [currentTool
        handleMouseDraggedFrom:[self convertPoint:[event locationInWindow] fromView:nil]
        delta:NSMakePoint(0, 0)
        forDocument:o_document];    

    [self mouseMoved:event];
}

- (void)mouseUp:(NSEvent *)event
{
    if([[[NSApp toolboxController] currentTool] isDestructive]) {
        [[o_document undoManager] endUndoGrouping];
    }

    [[self window] invalidateCursorRectsForView:self];    
    m_toolActive = NO;
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
    return [self _hoverValueFromBuffer:GL_COLOR_ATTACHMENT1_EXT];
}

- (struct point3)hoverNormal
{
    return [self _hoverValueFromBuffer:GL_COLOR_ATTACHMENT2_EXT];
}

- (struct point3)_hoverValueFromBuffer:(GLenum)buffer
{
    if(!m_hovering)
        return (struct point3){ -1, -1, -1 };

    float hoverPixelColor[4];
    
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, m_framebuffer);
    glReadBuffer(buffer);
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
