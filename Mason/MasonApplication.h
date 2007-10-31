#include <GL/glew.h>
#import <Cocoa/Cocoa.h>

@class MasonToolboxController;

@interface MasonApplication : NSApplication
{
    IBOutlet MasonToolboxController * o_toolboxController;
}

- (MasonToolboxController *)toolboxController;

@end
