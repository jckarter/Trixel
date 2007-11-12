#include <GL/glew.h>
#import <Cocoa/Cocoa.h>

@class MasonTool;

@interface MasonToolboxController : NSObject
{
    MasonTool * currentTool;
    BOOL showBoundingBox, showAxes, showLighting;
    IBOutlet NSMenuItem * o_showBoundingBoxItem, * o_showAxesItem, * o_showLightingItem;
}

@property(readonly) MasonTool * currentTool;
@property(readonly) BOOL showBoundingBox, showAxes, showLighting;

- (IBAction)changeCurrentTool:(id)sender;

- (IBAction)toggleShowBoundingBox:(id)sender;
- (IBAction)toggleShowAxes:(id)sender;
- (IBAction)toggleShowLighting:(id)sender;


@end
