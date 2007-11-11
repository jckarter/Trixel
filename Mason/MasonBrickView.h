#include <GL/glew.h>
#import <Cocoa/Cocoa.h>
#include "trixel.h"

@class MasonDocument;
@class MasonBrick;

@interface MasonBrickView : NSOpenGLView
{
    IBOutlet MasonDocument *o_document;

    BOOL m_hovering, m_toolActive;
    NSPoint m_hoverPixel;
    float m_yaw, m_pitch, m_distance;
    trixel_state m_t;
    
    GLuint m_vertex_buffer,
           m_framebuffer,
           m_color_texture,
           m_hover_renderbuffer, m_normal_renderbuffer, m_depth_renderbuffer;
    GLsizei m_normals_offset;
    struct slice_ops {
        char const * * trixel_flags;
        GLuint buffer_first, buffer_count;
        void (*set_up_state_func)(void);
    } m_slice_ops[4];
}

- (struct point3)hoverPoint;
- (struct point3)hoverNormal;
- (NSString *)hoverPointString;

- (void)yaw:(float)offset pitch:(float)offset;

@end
