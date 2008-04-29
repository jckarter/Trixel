#include <GL/glew.h>
#import <Cocoa/Cocoa.h>
#import "MasonViewAngle.h"

@class MasonTool;

@interface MasonToolboxController : NSObject
{
    MasonTool * currentTool;
    BOOL showBoundingBox, showAxes, showLighting, showSmoothShading, lockViewAngle;
    IBOutlet NSMenuItem * o_showBoundingBoxItem,
                        * o_showAxesItem,
                        * o_showLightingItem,
                        * o_showSmoothShadingItem,
                        * o_lockViewAngleItem;
    MasonViewAngle m_lockedViewAngle;
}

@property(readonly) MasonTool * currentTool;
@property(readonly) BOOL showBoundingBox, showAxes, showLighting, showSmoothShading, lockViewAngle;
@property(readonly) MasonViewAngle * lockedViewAngle;

- (IBAction)changeCurrentTool:(id)sender;

- (IBAction)toggleShowBoundingBox:(id)sender;
- (IBAction)toggleShowAxes:(id)sender;
- (IBAction)toggleShowLighting:(id)sender;
- (IBAction)toggleShowSmoothShading:(id)sender;
- (IBAction)toggleLockViewAngle:(id)sender;

@end
