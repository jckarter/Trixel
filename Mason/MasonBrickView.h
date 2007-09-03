#import <Cocoa/Cocoa.h>
#include <GL/glew.h>
#include "trixel.h"

@class MasonDocument;

@interface MasonBrickView : NSOpenGLView
{
    IBOutlet MasonDocument *o_document;

    NSTrackingRectTag m_trackingRect;
    BOOL m_initialized, m_hovering, m_toolActive;
    NSPoint m_hoverPixel;
    float m_yaw, m_pitch, m_distance;
    
    GLuint m_framebuffer, m_hover_renderbuffer, m_depth_renderbuffer, m_normal_renderbuffer, m_color_texture;
}

- (struct point3)hoverPoint;
- (NSString *)hoverPointString;

- (void)yaw:(float)offset pitch:(float)offset;

//private

- (void)_reshape_framebuffer;

@end
