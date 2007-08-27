#import <Cocoa/Cocoa.h>

@class MasonDocument;

@interface MasonBrickView : NSOpenGLView
{
    IBOutlet MasonDocument *o_document;

    float m_yaw, m_pitch, m_distance;
}
@end
