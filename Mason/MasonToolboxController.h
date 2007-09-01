#import <Cocoa/Cocoa.h>

@class MasonTool;

@interface MasonToolboxController : NSObject
{
    MasonTool * m_currentTool;
}

- (IBAction)changeCurrentTool:(id)sender;

- (MasonTool *)currentTool;

@end
