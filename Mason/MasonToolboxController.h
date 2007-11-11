#include <GL/glew.h>
#import <Cocoa/Cocoa.h>

@class MasonTool;

@interface MasonToolboxController : NSObject
{
    MasonTool * currentTool;
}

@property(readonly) MasonTool * currentTool;

- (IBAction)changeCurrentTool:(id)sender;

@end
