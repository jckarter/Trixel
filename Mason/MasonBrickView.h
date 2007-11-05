#include <GL/glew.h>
#import <Cocoa/Cocoa.h>
#include "trixel.h"

@class MasonDocument;
@class MasonBrick;

typedef void (*ElementRangeFunction)(NSInteger sliceNumber, GLuint *out_firstElement, GLsizei *out_numElements);

@interface MasonBrickView : NSOpenGLView
{
    IBOutlet MasonDocument *o_document;

    BOOL m_hovering, m_toolActive;
    NSPoint m_hoverPixel;
    float m_yaw, m_pitch, m_distance;
    trixel_state m_t;
    
    GLuint m_vertex_buffer, m_framebuffer, m_hover_renderbuffer, m_depth_renderbuffer, m_color_texture;
    struct slice_ops {
        char const * * trixel_flags;
        GLuint element_buffer;
		ElementRangeFunction element_range_function;
    } m_slice_ops[4];
}

- (struct point3)hoverPoint;
- (NSString *)hoverPointString;

- (void)yaw:(float)offset pitch:(float)offset;

//private
- (void)drawToFramebuffer;
- (void)drawBrick:(MasonBrick *)brick sliceAxis:(NSInteger)axis sliceNumber:(NSInteger)sliceNumber;
- (void)drawFramebufferToWindow;

- (void)_generate_framebuffer;
- (void)_destroy_framebuffer;

@end
