#import <Cocoa/Cocoa.h>
#include <GL/glew.h>

@class MasonDocument;

struct point3 {
    float x, y, z;
};

@interface MasonBrickView : NSOpenGLView
{
    IBOutlet MasonDocument *o_document;

    NSTrackingRectTag m_trackingRect;
    BOOL m_initialized, m_hovering;
    NSPoint m_hoverPixel;
    float m_yaw, m_pitch, m_distance;
    
    GLuint m_framebuffer, m_hover_texture, m_depth_renderbuffer, m_color_texture;
}

- (struct point3)hoverPoint;
- (NSString *)hoverPointString;

//private

- (void)_reshape_framebuffer;

@end
