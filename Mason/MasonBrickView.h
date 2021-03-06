#include <GL/glew.h>
#import <Cocoa/Cocoa.h>
#include "trixel.h"
#import "MasonViewAngle.h"

@class MasonDocument;
@class MasonBrick;

@interface MasonBrickView : NSOpenGLView
{
    IBOutlet MasonDocument *o_document;

    BOOL m_hovering, m_toolActive, m_brickNeedsPreparing;
    NSPoint m_hoverPixel;
    MasonViewAngle m_viewAngle;
    trixel_state m_t;
    
    GLuint m_vertex_buffer,
           m_framebuffer,
           m_color_texture,
           m_hover_renderbuffer, m_normal_renderbuffer, m_depth_renderbuffer;
    GLsizei m_normals_offset;
    struct slice_ops {
        int trixel_flags;
        GLuint buffer_first, buffer_count;
        void (*set_up_state_func)(void);
    } m_slice_ops[4];
}

- (struct point3)hoverPoint;
- (struct point3)hoverNormal;
- (NSString *)hoverPointString;

- (void)yaw:(float)offset pitch:(float)offset;
- (void)lightYaw:(float)offset pitch:(float)offset;

@end
