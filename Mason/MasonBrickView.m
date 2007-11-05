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

static const size_t g_num_draw_buffers = 2;
static const GLenum g_tool_inactive_draw_buffers[] = { GL_COLOR_ATTACHMENT0_EXT, GL_COLOR_ATTACHMENT1_EXT };
static const GLenum g_tool_active_draw_buffers[]   = { GL_COLOR_ATTACHMENT0_EXT, GL_NONE                  };

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
_surface_element_range_function(NSInteger sliceNumber, GLuint *out_firstElement, GLsizei *out_numElements)
{
    *out_firstElement = 0;
    *out_numElements  = 24;
}

void
_slice_element_range_function(NSInteger sliceNumber, GLuint *out_firstElement, GLsizei *out_numElements)
{
    *out_firstElement = sliceNumber * 8;
    *out_numElements = 8;
}

static inline GLvoid *
_short_buffer_offset(GLuint offset)
{
    return (GLvoid *)((char*)NULL + offset*sizeof(GLshort));
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
    
    [[NSApp toolboxController] addObserver:self forKeyPath:@"currentTool" options:NSKeyValueObservingOptionNew context:NULL];
    [[o_document brick] addObserver:self forKeyPath:@"voxmap" options:NSKeyValueObservingOptionNew context:NULL];
    [[o_document brick] addObserver:self forKeyPath:@"paletteColors" options:NSKeyValueObservingOptionNew context:NULL];
    [o_document addObserver:self forKeyPath:@"sliceAxis" options:NSKeyValueObservingOptionNew context:NULL];
    [o_document addObserver:self forKeyPath:@"sliceNumber" options:NSKeyValueObservingOptionNew context:NULL];
    
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
        
        [self setNeedsDisplay:YES];
    }
    else if(object == o_document || object == [o_document brick])
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
    
    MasonBrick * brick = [o_document brick];

    int    width = [brick width], height = [brick height], depth = [brick depth],
           width_elt_offset = 2 * 4, height_elt_offset = (2 + width) * 4, depth_elt_offset = (2 + width + height) * 4,
           width_offset = width_elt_offset * 3, height_offset = height_elt_offset * 3, depth_offset = depth_elt_offset * 3;
    size_t vertex_count = (2 + width + height + depth) * 12;
    GLfloat vertices[vertex_count];
    
    vertices[ 0] = -width/2;
    vertices[ 1] = -height/2;
    vertices[ 2] = -depth/2;
    
    vertices[ 3] = -width/2;
    vertices[ 4] = -height/2;
    vertices[ 5] =  depth/2;
    
    vertices[ 6] = -width/2;
    vertices[ 7] =  height/2;
    vertices[ 8] =  depth/2;
    
    vertices[ 9] = -width/2;
    vertices[10] =  height/2;
    vertices[11] = -depth/2;
        
    vertices[12] =  width/2;
    vertices[13] = -height/2;
    vertices[14] = -depth/2;
    
    vertices[15] =  width/2;
    vertices[16] = -height/2;
    vertices[17] =  depth/2;
    
    vertices[18] =  width/2;
    vertices[19] =  height/2;
    vertices[20] =  depth/2;
    
    vertices[21] =  width/2;
    vertices[22] =  height/2;
    vertices[23] = -depth/2;
        
    unsigned i;
    for(i = 0; i < width; ++i) {
        GLfloat w = (GLfloat)i + 0.5 - width/2;
        vertices[width_offset + i * 12 +  0] =  w;
        vertices[width_offset + i * 12 +  1] = -height/2;
        vertices[width_offset + i * 12 +  2] = -depth/2;
        
        vertices[width_offset + i * 12 +  3] =  w;
        vertices[width_offset + i * 12 +  4] =  height/2;
        vertices[width_offset + i * 12 +  5] = -depth/2;
        
        vertices[width_offset + i * 12 +  6] =  w;
        vertices[width_offset + i * 12 +  7] =  height/2;
        vertices[width_offset + i * 12 +  8] =  depth/2;
        
        vertices[width_offset + i * 12 +  9] =  w;
        vertices[width_offset + i * 12 + 10] = -height/2;
        vertices[width_offset + i * 12 + 11] =  depth/2;
    }
    for(i = 0; i < height; ++i) {
        GLfloat h = (GLfloat)i + 0.5 - height/2;
        vertices[height_offset + i * 12 +  0] = -width/2;
        vertices[height_offset + i * 12 +  1] =  h;
        vertices[height_offset + i * 12 +  2] = -depth/2;

        vertices[height_offset + i * 12 +  3] =  width/2;
        vertices[height_offset + i * 12 +  4] =  h;
        vertices[height_offset + i * 12 +  5] = -depth/2;

        vertices[height_offset + i * 12 +  6] =  width/2;
        vertices[height_offset + i * 12 +  7] =  h;
        vertices[height_offset + i * 12 +  8] =  depth/2;

        vertices[height_offset + i * 12 +  9] = -width/2;
        vertices[height_offset + i * 12 + 10] =  h;
        vertices[height_offset + i * 12 + 11] =  depth/2;
    }
    for(i = 0; i < depth; ++i) {
        GLfloat d = (GLfloat)i + 0.5 - depth/2;
        vertices[depth_offset + i * 12 +  0] = -width/2;
        vertices[depth_offset + i * 12 +  1] = -height/2;
        vertices[depth_offset + i * 12 +  2] =  d;

        vertices[depth_offset + i * 12 +  3] =  width/2;
        vertices[depth_offset + i * 12 +  4] = -height/2;
        vertices[depth_offset + i * 12 +  5] =  d;

        vertices[depth_offset + i * 12 +  6] =  width/2;
        vertices[depth_offset + i * 12 +  7] =  height/2;
        vertices[depth_offset + i * 12 +  8] =  d;

        vertices[depth_offset + i * 12 +  9] = -width/2;
        vertices[depth_offset + i * 12 + 10] =  height/2;
        vertices[depth_offset + i * 12 + 11] =  d;
    }
    
    glGenBuffers(1, &m_vertex_buffer);
    glBindBuffer(GL_ARRAY_BUFFER, m_vertex_buffer);
    glBufferData(GL_ARRAY_BUFFER, vertex_count * sizeof(GLfloat), vertices, GL_STATIC_DRAW);

    m_slice_ops[SLICE_AXIS_SURFACE].trixel_flags = g_surface_flags;
    glGenBuffers(1, &m_slice_ops[SLICE_AXIS_SURFACE].element_buffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, m_slice_ops[SLICE_AXIS_SURFACE].element_buffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(g_surface_elements), g_surface_elements, GL_STATIC_DRAW);
    m_slice_ops[SLICE_AXIS_SURFACE].element_range_function = _surface_element_range_function;

    m_slice_ops[SLICE_AXIS_XAXIS].trixel_flags = g_slice_flags;
    GLshort xaxis_elements[width * 8];
    for(i = 0; i < width; ++i) {
        xaxis_elements[i*8 + 0] = width_elt_offset + i*4 + 0;
        xaxis_elements[i*8 + 1] = width_elt_offset + i*4 + 1;
        xaxis_elements[i*8 + 2] = width_elt_offset + i*4 + 2;
        xaxis_elements[i*8 + 3] = width_elt_offset + i*4 + 3;
        
        xaxis_elements[i*8 + 4] = width_elt_offset + i*4 + 3;
        xaxis_elements[i*8 + 5] = width_elt_offset + i*4 + 2;
        xaxis_elements[i*8 + 6] = width_elt_offset + i*4 + 1;
        xaxis_elements[i*8 + 7] = width_elt_offset + i*4 + 0;
    }
    glGenBuffers(1, &m_slice_ops[SLICE_AXIS_XAXIS].element_buffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, m_slice_ops[SLICE_AXIS_XAXIS].element_buffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(GLshort) * width * 8, xaxis_elements, GL_STATIC_DRAW);
    m_slice_ops[SLICE_AXIS_XAXIS].element_range_function = _slice_element_range_function;

    m_slice_ops[SLICE_AXIS_YAXIS].trixel_flags = g_slice_flags;
    GLshort yaxis_elements[height * 8];
    for(i = 0; i < height; ++i) {
        yaxis_elements[i*8 + 0] = height_elt_offset + i*4 + 0;
        yaxis_elements[i*8 + 1] = height_elt_offset + i*4 + 1;
        yaxis_elements[i*8 + 2] = height_elt_offset + i*4 + 2;
        yaxis_elements[i*8 + 3] = height_elt_offset + i*4 + 3;
        
        yaxis_elements[i*8 + 4] = height_elt_offset + i*4 + 3;
        yaxis_elements[i*8 + 5] = height_elt_offset + i*4 + 2;
        yaxis_elements[i*8 + 6] = height_elt_offset + i*4 + 1;
        yaxis_elements[i*8 + 7] = height_elt_offset + i*4 + 0;
    }
    glGenBuffers(1, &m_slice_ops[SLICE_AXIS_YAXIS].element_buffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, m_slice_ops[SLICE_AXIS_YAXIS].element_buffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(GLshort) * height * 8, yaxis_elements, GL_STATIC_DRAW);
    m_slice_ops[SLICE_AXIS_YAXIS].element_range_function = _slice_element_range_function;

    m_slice_ops[SLICE_AXIS_ZAXIS].trixel_flags = g_slice_flags;
    GLshort zaxis_elements[depth * 8];
    for(i = 0; i < depth; ++i) {
        zaxis_elements[i*8 + 0] = depth_elt_offset + i*4 + 0;
        zaxis_elements[i*8 + 1] = depth_elt_offset + i*4 + 1;
        zaxis_elements[i*8 + 2] = depth_elt_offset + i*4 + 2;
        zaxis_elements[i*8 + 3] = depth_elt_offset + i*4 + 3;
        
        zaxis_elements[i*8 + 4] = depth_elt_offset + i*4 + 3;
        zaxis_elements[i*8 + 5] = depth_elt_offset + i*4 + 2;
        zaxis_elements[i*8 + 6] = depth_elt_offset + i*4 + 1;
        zaxis_elements[i*8 + 7] = depth_elt_offset + i*4 + 0;
    }
    glGenBuffers(1, &m_slice_ops[SLICE_AXIS_ZAXIS].element_buffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, m_slice_ops[SLICE_AXIS_ZAXIS].element_buffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(GLshort) * depth * 8, zaxis_elements, GL_STATIC_DRAW);
    m_slice_ops[SLICE_AXIS_ZAXIS].element_range_function = _slice_element_range_function;

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);    

    [brick prepare];

    [self _generate_framebuffer];
}

- (void)reshape
{
    if(!m_t)
        return;

    NSRect frame = [self bounds];
    
    [[self window] invalidateCursorRectsForView:self];
    
    trixel_reshape(m_t, NSWidth(frame), NSHeight(frame));
        
    [[self openGLContext] update];
    [self _generate_framebuffer];
    [self setNeedsDisplay:YES];
}

- (void)yaw:(float)yoffset pitch:(float)poffset
{
    m_yaw = m_yaw + yoffset * MOUSE_ROTATE_FACTOR;
    m_pitch = fbound(m_pitch + poffset * MOUSE_ROTATE_FACTOR, -90.0, 90.0);
    [self setNeedsDisplay:YES];
}

- (void)_generate_framebuffer
{
    if(m_framebuffer)
        [self _destroy_framebuffer];

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

    glGenRenderbuffersEXT(1, &m_depth_renderbuffer);
    glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, m_depth_renderbuffer);
    glRenderbufferStorageEXT(GL_RENDERBUFFER_EXT, GL_DEPTH_COMPONENT32, NSWidth(frame), NSHeight(frame));
    
    glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_2D, m_color_texture, 0);
    glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT1_EXT, GL_RENDERBUFFER_EXT, m_hover_renderbuffer);
    glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_DEPTH_ATTACHMENT_EXT,  GL_RENDERBUFFER_EXT, m_depth_renderbuffer);

    if(glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT) != GL_FRAMEBUFFER_COMPLETE_EXT)
    {
        NSLog(@"framebuffer not complete %d", glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT));
    }
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);
}

- (void)_destroy_framebuffer
{
    glDeleteFramebuffersEXT(1, &m_framebuffer);
    glDeleteTextures(1, &m_color_texture);
    glDeleteRenderbuffersEXT(1, &m_hover_renderbuffer);
    glDeleteRenderbuffersEXT(1, &m_depth_renderbuffer);
    
    m_framebuffer = m_color_texture = m_hover_renderbuffer = m_depth_renderbuffer = 0;
}

- (void)drawToFramebuffer
{
    const GLenum *draw_buffers = (m_toolActive ? g_tool_active_draw_buffers : g_tool_inactive_draw_buffers);
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, m_framebuffer);

    glDrawBuffers(g_num_draw_buffers - 1, draw_buffers + 1);
    glClearColor(0.0, 0.0, 0.0, 0.0);
    glClear(GL_COLOR_BUFFER_BIT);

    glDrawBuffer(draw_buffers[0]);
    glClearColor(0.2, 0.2, 0.2, 1.0);    
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glDrawBuffers(g_num_draw_buffers, draw_buffers);

    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    glTranslatef(0.0, 0.0, -m_distance);
    glRotatef(m_pitch, 1.0, 0.0, 0.0);
    glRotatef(m_yaw,   0.0, 1.0, 0.0);
}

- (void)drawBrick:(MasonBrick *)brick sliceAxis:(NSInteger)axis sliceNumber:(NSInteger)sliceNumber
{
    [brick useForDrawing:m_t];

    GLuint offset;
    GLsizei count;
    m_slice_ops[axis].element_range_function(sliceNumber, &offset, &count);

    glEnableClientState(GL_VERTEX_ARRAY);

    glBindBuffer(GL_ARRAY_BUFFER, m_vertex_buffer);
    glVertexPointer(3, GL_FLOAT, 0, 0);    

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, m_slice_ops[axis].element_buffer);    
    glDrawElements(GL_QUADS, count, GL_UNSIGNED_SHORT, _short_buffer_offset(offset));
    
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
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

- (void)drawFramebufferToWindow
{
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);
    glDrawBuffer(GL_BACK);
    glMatrixMode(GL_PROJECTION);
    glPushMatrix();
    glLoadIdentity();
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    
    glUseProgram(0);
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
    [self drawToFramebuffer];
    [self drawBoundingCubeForBrick:[o_document brick]];
    [self drawAxesForBrick:[o_document brick]];    
    [self drawBrick:[o_document brick] sliceAxis:[o_document sliceAxis] sliceNumber:[o_document sliceNumber]];
    
    [self drawFramebufferToWindow];
    
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
