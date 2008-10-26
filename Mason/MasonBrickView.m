#import "MasonBrickView.h"
#import "MasonDocument.h"
#import "MasonApplication.h"
#import "MasonToolboxController.h"
#import "MasonTool.h"
#import "MasonBrick.h"
#import "MasonCubeSelection.h"
#include <math.h>

#include "trixel.h"

static const size_t g_num_draw_buffers = 3;
static const GLenum g_tool_inactive_draw_buffers[] = { GL_COLOR_ATTACHMENT0_EXT, GL_COLOR_ATTACHMENT1_EXT, GL_COLOR_ATTACHMENT2_EXT };
static const GLenum g_tool_active_draw_buffers[]   = { GL_COLOR_ATTACHMENT0_EXT, GL_NONE,                  GL_NONE                  };

static const int g_surface_flags = TRIXEL_SMOOTH_SHADING | TRIXEL_LIGHTING | TRIXEL_SAVE_COORDINATES | TRIXEL_EXACT_DEPTH;
static const int g_slice_flags = TRIXEL_SAVE_COORDINATES | TRIXEL_SURFACE_ONLY;
static const GLshort g_surface_elements[] = {
    0, 1, 2, 3,
    0, 4, 5, 1,
    4, 7, 6, 5,
    3, 2, 6, 7,
    0, 3, 7, 4,
    2, 1, 5, 6
};

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
- (void)_drawHover;
- (void)_drawFramebufferToWindow;

- (void)_generateFramebuffer;
- (void)_prepareBrick;
- (void)_prepareVertexBufferForBrick:(MasonBrick *)brick;
- (void)_destroyFramebuffer;

- (int)_trixelFlags;
- (void)_updateLightParams;
- (void)_updateShaders;

- (struct point3)_hoverValueFromBuffer:(GLenum)buffer;

- (MasonViewAngle *)_viewAngle;

- (void)_willRotate;
- (void)_didRotate;

@end

@implementation MasonBrickView

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
    if([key isEqualToString:@"hoverPoint"] || [key isEqualToString:@"hoverNormal"])
        return NO;
    else
        return [super automaticallyNotifiesObserversForKey:key];
}

+ (void)initialize
{
    [self setKeys:[NSArray arrayWithObject:@"hoverPoint"]
          triggerChangeNotificationsForDependentKey:@"hoverPointString"];
}

- (MasonViewAngle *)_viewAngle
{
    return [NSApp toolboxController].lockViewAngle
        ? [NSApp toolboxController].lockedViewAngle
        : &m_viewAngle;
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
    
    MasonViewAngleInitialize(&m_viewAngle);
    m_hovering = NO;
    m_toolActive = NO;
    m_brickNeedsPreparing = YES;
    
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
            
    [[NSApp toolboxController] addObserver:self forKeyPath:@"lockViewAngle" options:NSKeyValueObservingOptionOld context:NULL];
    [[NSApp toolboxController] addObserver:self forKeyPath:@"lockedViewAngle" options:NSKeyValueObservingOptionOld context:NULL];
    [[NSApp toolboxController] addObserver:self forKeyPath:@"currentTool" options:NSKeyValueObservingOptionOld context:NULL];
    [[NSApp toolboxController] addObserver:self forKeyPath:@"showBoundingBox" options:NSKeyValueObservingOptionOld context:NULL];
    [[NSApp toolboxController] addObserver:self forKeyPath:@"showAxes" options:NSKeyValueObservingOptionOld context:NULL];
    [[NSApp toolboxController] addObserver:self forKeyPath:@"showLighting" options:NSKeyValueObservingOptionOld context:NULL];
    [[NSApp toolboxController] addObserver:self forKeyPath:@"showSmoothShading" options:NSKeyValueObservingOptionOld context:NULL];
    [o_document addObserver:self forKeyPath:@"sliceAxis" options:NSKeyValueObservingOptionOld context:NULL];
    [o_document addObserver:self forKeyPath:@"selection" options:NSKeyValueObservingOptionOld context:NULL];
    [o_document addObserver:self forKeyPath:@"sliceNumber" options:NSKeyValueObservingOptionOld context:NULL];
    [o_document addObserver:self forKeyPath:@"brick" options:NSKeyValueObservingOptionOld context:NULL];
    [[o_document brick] addObserver:self forKeyPath:@"voxmap" options:NSKeyValueObservingOptionOld context:NULL];
    [[o_document brick] addObserver:self forKeyPath:@"paletteColors" options:NSKeyValueObservingOptionOld context:NULL];
    
    [[self window] invalidateCursorRectsForView:self];
}

- (void)finalize
{
    trixel_state_free(m_t);
    [super finalize];
}

- (int)_trixelFlags
{
    int base_flags = m_slice_ops[ [o_document sliceAxis] ].trixel_flags;

    if(![NSApp toolboxController].showLighting)
        base_flags &= ~(TRIXEL_SMOOTH_SHADING | TRIXEL_LIGHTING);
    if(![NSApp toolboxController].showSmoothShading)
        base_flags &= ~(TRIXEL_SMOOTH_SHADING);

    return base_flags;
}

- (void)_updateLightParams
{
    if([NSApp toolboxController].showLighting) {
        GLfloat cosp = cosf([self _viewAngle]->light.pitch * RADIANS),
                sinp = sinf([self _viewAngle]->light.pitch * RADIANS),
                cosy = cosf([self _viewAngle]->light.yaw   * RADIANS),
                siny = sinf([self _viewAngle]->light.yaw   * RADIANS);
        
        GLfloat position[4] = {
             cosp * siny * LIGHT_DISTANCE,
             sinp * LIGHT_DISTANCE,
            -cosp * cosy * LIGHT_DISTANCE,
             1.0
        };
        GLfloat ambient[4]  = { 0.3, 0.3, 0.3, 1.0 };
        GLfloat diffuse[4]  = { 0.7, 0.7, 0.7, 1.0 };

        trixel_light_param(m_t, 0, TRIXEL_LIGHT_PARAM_POSITION, position);
        trixel_light_param(m_t, 0, TRIXEL_LIGHT_PARAM_AMBIENT,  ambient );
        trixel_light_param(m_t, 0, TRIXEL_LIGHT_PARAM_DIFFUSE,  diffuse );
    }
    m_slice_ops[ [o_document sliceAxis] ].set_up_state_func();
}

- (void)_updateShaders
{
    char * error;
    
    NSOpenGLContext * currentContext = [NSOpenGLContext currentContext];
    
    [[self openGLContext] makeCurrentContext];
    
    if(!trixel_update_shaders(m_t, [self _trixelFlags], &error)) {
        NSLog(@"error resetting trixel flags!! %s", error); // XXX real error handling
        free(error);
    }

    [self _updateLightParams];
    [currentContext makeCurrentContext];
}

- (void)observeValueForKeyPath:(NSString*)path ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if(object == [NSApp toolboxController] && [path isEqualToString:@"currentTool"]) {
        [[self window] invalidateCursorRectsForView:self];
    }
    else if(object == [NSApp toolboxController]
            && ([path isEqualToString:@"lockedViewAngle"] || [path isEqualToString:@"lockViewAngle"])) {
        [self _updateLightParams];
        [self setNeedsDisplay:YES];
    }
    else if(object == [NSApp toolboxController]
            && ([path isEqualToString:@"showBoundingBox"] || [path isEqualToString:@"showAxes"])) {
        [self setNeedsDisplay:YES];
    }
    else if(((object == o_document && [path isEqualToString:@"sliceAxis"])
                || (object == [NSApp toolboxController] && [path isEqualToString:@"showLighting"])
                || (object == [NSApp toolboxController] && [path isEqualToString:@"showSmoothShading"]))
            && m_t) {
        [self _updateShaders];
        [self setNeedsDisplay:YES];
    }
    else if(object == o_document && [path isEqualToString:@"brick"]) {
        MasonBrick * oldBrick = [change objectForKey:NSKeyValueChangeOldKey];
        [oldBrick removeObserver:self forKeyPath:@"voxmap"];
        [oldBrick removeObserver:self forKeyPath:@"paletteColors"];
        [oldBrick unprepare];
        [o_document.brick addObserver:self forKeyPath:@"voxmap" options:NSKeyValueObservingOptionOld context:NULL];
        [o_document.brick addObserver:self forKeyPath:@"paletteColors" options:NSKeyValueObservingOptionOld context:NULL];

        m_brickNeedsPreparing = YES;
        [self setNeedsDisplay:YES];
    }
    else if(object == o_document
            && ([path isEqualToString:@"sliceNumber"] || [path isEqualToString:@"selection"])) {
        [self setNeedsDisplay:YES];
    }
    else if(object == [o_document brick]) {
        m_brickNeedsPreparing = YES;
        [self setNeedsDisplay:YES];
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

- (void)_prepareBrick
{
    if (!m_t) return;

    [self _prepareVertexBufferForBrick:o_document.brick];
    [o_document.brick prepare:m_t];
    m_brickNeedsPreparing = NO;
}

- (void)_prepareVertexBufferForBrick:(MasonBrick *)brick
{
    int width = brick.width, height = brick.height, depth = brick.depth;
        
    int width_elt_offset = 0,
        height_elt_offset = width_elt_offset + width * 8,
        depth_elt_offset = height_elt_offset + height * 8;
    
    int width_offset = width_elt_offset * 3,
        height_offset = height_elt_offset * 3,
        depth_offset = depth_elt_offset * 3;
    size_t vertex_count = ((width + height + depth) * 8) * 12;
    
    GLbyte buffer[vertex_count * (sizeof(GLfloat) + sizeof(GLbyte))];

    m_normals_offset = vertex_count * sizeof(GLfloat);
    
    GLfloat * vertices = (GLfloat *)buffer;
    GLbyte  * normals  = buffer + m_normals_offset;
    
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
    m_slice_ops[SLICE_AXIS_SURFACE].buffer_first = -1;
    m_slice_ops[SLICE_AXIS_SURFACE].buffer_count = -1;    
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
        g_surface_flags,
        &error_message
    );
    
    if(!m_t) {
        NSLog(@"%s", error_message); // xxx proper error handling
        return;
    }

    glGenBuffers(1, &m_vertex_buffer);    

    [self _prepareBrick];
    [self _generateFramebuffer];
    [self _updateLightParams];
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

- (void)_willRotate
{
    if([NSApp toolboxController].lockViewAngle)
        [[NSApp toolboxController] willChangeValueForKey:@"lockViewAngle"];
}

- (void)_didRotate
{
    if([NSApp toolboxController].lockViewAngle)
        [[NSApp toolboxController] didChangeValueForKey:@"lockViewAngle"];
}

- (void)yaw:(float)yoffset pitch:(float)poffset
{
    [self _willRotate];
    MasonViewRotationYawPitch(&[self _viewAngle]->eye, yoffset, poffset);
    [self setNeedsDisplay:YES];
    [self _didRotate];
}

- (void)lightYaw:(float)yoffset pitch:(float)poffset
{
    [self _willRotate];
    MasonViewRotationYawPitch(&[self _viewAngle]->light, yoffset, -poffset);
    [self _updateLightParams];
    [self setNeedsDisplay:YES];
    [self _didRotate];
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
    if (m_slice_ops[axis].buffer_first == (unsigned)-1)
    {
        [brick draw];
    } else {
        [brick useForDrawing];

        GLint first = m_slice_ops[axis].buffer_first;
        GLsizei count = m_slice_ops[axis].buffer_count;

        glEnableClientState(GL_VERTEX_ARRAY);
        glEnableClientState(GL_NORMAL_ARRAY);

        glBindBuffer(GL_ARRAY_BUFFER, m_vertex_buffer);
        glVertexPointer(3, GL_FLOAT, 0, 0);
        glNormalPointer(GL_BYTE, 0, (void*)m_normals_offset);

        glDrawArrays(GL_QUADS, first + count * sliceNumber, count);
    
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glDisableClientState(GL_VERTEX_ARRAY);
        glDisableClientState(GL_NORMAL_ARRAY);
    }
}

- (void)drawBoundingCubeForBrick:(MasonBrick *)brick
{
    float width2  = ((float)[brick width] ) / 2,
          height2 = ((float)[brick height]) / 2,
          depth2  = ((float)[brick depth] ) / 2,
          minx = -width2  + (float)o_document.selection.minx,
          miny = -height2 + (float)o_document.selection.miny,
          minz = -depth2  + (float)o_document.selection.minz,
          maxx = -width2  + (float)o_document.selection.maxx,
          maxy = -height2 + (float)o_document.selection.maxy,
          maxz = -depth2  + (float)o_document.selection.maxz;
    
    glUseProgram(0);
    glActiveTexture(GL_TEXTURE0);
    glDisable(GL_TEXTURE_2D);
    
    glBegin(GL_LINES);

    glColor4f(0.5, 0.4, 0.4, 1.0);
    glVertex3f(minx, miny, minz);
    glVertex3f(minx, miny, maxz);

    glVertex3f(minx, maxy, minz);
    glVertex3f(minx, maxy, maxz);

    glVertex3f( maxx,  maxy, minz);
    glVertex3f( maxx,  maxy,  maxz);

    glVertex3f( maxx, miny, minz);
    glVertex3f( maxx, miny,  maxz);
    
    glColor4f(0.4, 0.5, 0.4, 1.0);
    glVertex3f(minx, miny, minz);
    glVertex3f(minx,  maxy, minz);

    glVertex3f( maxx, miny, minz);
    glVertex3f( maxx,  maxy, minz);

    glVertex3f( maxx, miny,  maxz);
    glVertex3f( maxx,  maxy,  maxz);

    glVertex3f(minx, miny,  maxz);
    glVertex3f(minx,  maxy,  maxz);

    glColor4f(0.4, 0.4, 0.5, 1.0);
    glVertex3f(minx, miny, minz);
    glVertex3f( maxx, miny, minz);

    glVertex3f(minx,  maxy, minz);
    glVertex3f( maxx,  maxy, minz);

    glVertex3f(minx,  maxy,  maxz);
    glVertex3f( maxx,  maxy,  maxz);

    glVertex3f(minx, miny,  maxz);
    glVertex3f( maxx, miny,  maxz);

    glEnd();
}

- (void)drawAxesForBrick:(MasonBrick *)brick
{
    float width2  = ((float)[brick width] ) / 2,
          height2 = ((float)[brick height]) / 2,
          depth2  = ((float)[brick depth] ) / 2;
    
    glUseProgram(0);
    glActiveTexture(GL_TEXTURE0);
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

#define HOVER_PADDING 0.015625

- (void)_drawHover
{
    struct point3 hoverPoint = [self hoverPoint];
    struct point3 hoverNormal = [self hoverNormal];
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, m_framebuffer);
    
    if(hoverPoint.x < 0.0)
        return;
        
    switch([[[NSApp toolboxController] currentTool] unit]) {
    case MasonUnitNone:
        break;

    case MasonUnitVoxel:
        {
            struct point3 hoverStartPoint = add_point3(
                    hoverPoint,
                    POINT3(-(float)[o_document brick].width /2-HOVER_PADDING,
                           -(float)[o_document brick].height/2-HOVER_PADDING,
                           -(float)[o_document brick].depth /2-HOVER_PADDING)
            );
            struct point3 hoverEndPoint = add_point3(
                    hoverStartPoint,
                    POINT3(1+(HOVER_PADDING*2),
                           1+(HOVER_PADDING*2),
                           1+(HOVER_PADDING*2))
            );

            glUseProgram(0);
            glActiveTexture(GL_TEXTURE0);
            glDisable(GL_TEXTURE_2D);
        
            glBegin(GL_LINES);

            glColor4f(0.7, 0.5, 0.7, 1.0);
            glVertex3f(hoverStartPoint.x, hoverStartPoint.y, hoverStartPoint.z);
            glVertex3f(hoverStartPoint.x, hoverStartPoint.y,  hoverEndPoint.z);

            glVertex3f(hoverStartPoint.x,  hoverEndPoint.y, hoverStartPoint.z);
            glVertex3f(hoverStartPoint.x,  hoverEndPoint.y,  hoverEndPoint.z);

            glVertex3f( hoverEndPoint.x,  hoverEndPoint.y, hoverStartPoint.z);
            glVertex3f( hoverEndPoint.x,  hoverEndPoint.y,  hoverEndPoint.z);

            glVertex3f( hoverEndPoint.x, hoverStartPoint.y, hoverStartPoint.z);
            glVertex3f( hoverEndPoint.x, hoverStartPoint.y,  hoverEndPoint.z);
    
            glVertex3f(hoverStartPoint.x, hoverStartPoint.y, hoverStartPoint.z);
            glVertex3f(hoverStartPoint.x,  hoverEndPoint.y, hoverStartPoint.z);

            glVertex3f( hoverEndPoint.x, hoverStartPoint.y, hoverStartPoint.z);
            glVertex3f( hoverEndPoint.x,  hoverEndPoint.y, hoverStartPoint.z);

            glVertex3f( hoverEndPoint.x, hoverStartPoint.y,  hoverEndPoint.z);
            glVertex3f( hoverEndPoint.x,  hoverEndPoint.y,  hoverEndPoint.z);

            glVertex3f(hoverStartPoint.x, hoverStartPoint.y,  hoverEndPoint.z);
            glVertex3f(hoverStartPoint.x,  hoverEndPoint.y,  hoverEndPoint.z);

            glVertex3f(hoverStartPoint.x, hoverStartPoint.y, hoverStartPoint.z);
            glVertex3f( hoverEndPoint.x, hoverStartPoint.y, hoverStartPoint.z);

            glVertex3f(hoverStartPoint.x,  hoverEndPoint.y, hoverStartPoint.z);
            glVertex3f( hoverEndPoint.x,  hoverEndPoint.y, hoverStartPoint.z);

            glVertex3f(hoverStartPoint.x,  hoverEndPoint.y,  hoverEndPoint.z);
            glVertex3f( hoverEndPoint.x,  hoverEndPoint.y,  hoverEndPoint.z);

            glVertex3f(hoverStartPoint.x, hoverStartPoint.y,  hoverEndPoint.z);
            glVertex3f( hoverEndPoint.x, hoverStartPoint.y,  hoverEndPoint.z);
        
            glEnd();
        }
        break;

    case MasonUnitFace:
        {
            struct point3 hoverTranslate = add_point3(
                hoverPoint,
                POINT3(0.5 - (float)[o_document brick].width /2,
                       0.5 - (float)[o_document brick].height/2,
                       0.5 - (float)[o_document brick].depth /2)
            );
            
            GLfloat hoverOrientMatrix[] = {
                hoverNormal.x, hoverNormal.y, hoverNormal.z, 0,
                hoverNormal.y, hoverNormal.z, hoverNormal.x, 0,
                hoverNormal.z, hoverNormal.x, hoverNormal.y, 0,
                0,             0,             0,             1
            };
            
            glUseProgram(0);
            glActiveTexture(GL_TEXTURE0);
            glDisable(GL_TEXTURE_2D);

            glMatrixMode(GL_MODELVIEW);
            glPushMatrix();
            glTranslatef(hoverTranslate.x, hoverTranslate.y, hoverTranslate.z);
            glMultMatrixf(hoverOrientMatrix);
    
            glBegin(GL_LINE_LOOP);

            glColor4f(0.7, 0.5, 0.7, 1.0);
            glVertex3f( 0.5+HOVER_PADDING, -0.5-HOVER_PADDING, -0.5-HOVER_PADDING);
            glVertex3f( 0.5+HOVER_PADDING,  0.5-HOVER_PADDING, -0.5-HOVER_PADDING);
            glVertex3f( 0.5+HOVER_PADDING,  0.5-HOVER_PADDING,  0.5-HOVER_PADDING);
            glVertex3f( 0.5+HOVER_PADDING, -0.5-HOVER_PADDING,  0.5-HOVER_PADDING);

            glEnd();
            
            glPopMatrix();
        }
        break;
    }
}

- (void)drawRect:(NSRect)r
{
    if(m_brickNeedsPreparing)
        [self _prepareBrick];

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
    
    MasonViewAngle * viewAngle = [self _viewAngle];
    
    glTranslatef(0.0, 0.0, -viewAngle->distance);
    glRotatef(viewAngle->eye.pitch, 1.0, 0.0, 0.0);
    glRotatef(viewAngle->eye.yaw,   0.0, 1.0, 0.0);

    if([[NSApp toolboxController] showBoundingBox])
        [self drawBoundingCubeForBrick:[o_document brick]];
    if([[NSApp toolboxController] showAxes])
        [self drawAxesForBrick:[o_document brick]];    

    glDrawBuffers(g_num_draw_buffers, draw_buffers);
    [self _drawBrick:[o_document brick] sliceAxis:[o_document sliceAxis] sliceNumber:[o_document sliceNumber]];
    glDrawBuffer(draw_buffers[0]);
    [self _drawHover];
    
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
    [self _willRotate];
    [self _viewAngle]->distance = fmax([self _viewAngle]->distance - [event deltaY], 0.0);
    [self _didRotate];
    
    [self setNeedsDisplay:YES];
}

- (void)mouseEntered:(NSEvent *)event
{
    [self willChangeValueForKey:@"hoverPoint"];
    [self willChangeValueForKey:@"hoverNormal"];
    m_hovering = YES;
    [self didChangeValueForKey:@"hoverPoint"];
    [self didChangeValueForKey:@"hoverNormal"];
    [self hoverPoint];
    [self hoverNormal];
}

- (void)mouseMoved:(NSEvent *)event
{
    if(!m_hovering)
        return;

    [self willChangeValueForKey:@"hoverPoint"];
    [self willChangeValueForKey:@"hoverNormal"];
    m_hoverPixel = [self convertPoint:[event locationInWindow] fromView:nil];
    [self didChangeValueForKey:@"hoverPoint"];
    [self didChangeValueForKey:@"hoverNormal"];
    [self hoverPoint];
    [self hoverNormal];
}

- (void)mouseExited:(NSEvent *)event
{
    [self willChangeValueForKey:@"hoverPoint"];
    [self willChangeValueForKey:@"hoverNormal"];
    m_hovering = NO;
    [self didChangeValueForKey:@"hoverPoint"];
    [self didChangeValueForKey:@"hoverNormal"];
    [self hoverPoint];
    [self hoverNormal];
}

- (struct point3)hoverPoint
{
    static struct point3 prevHoverPoint = { -1, -1, -1 };
    struct point3 newHoverPoint = [self _hoverValueFromBuffer:GL_COLOR_ATTACHMENT1_EXT];
    if(!eq_point3(prevHoverPoint, newHoverPoint))
        [self setNeedsDisplay:YES];
    return prevHoverPoint = newHoverPoint;
}

- (struct point3)hoverNormal
{
    static struct point3 prevHoverNormal = { 0, 0, 0 };
    struct point3 newHoverNormal = [self _hoverValueFromBuffer:GL_COLOR_ATTACHMENT2_EXT];
    if(!eq_point3(prevHoverNormal, newHoverNormal))
        [self setNeedsDisplay:YES];
    return prevHoverNormal = newHoverNormal;
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
