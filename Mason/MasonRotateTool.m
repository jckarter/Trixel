#import "MasonRotateTool.h"
#import "MasonDocument.h"
#import "MasonBrickView.h"

@implementation MasonRotateTool

- (void)handleMouseDraggedFrom:(NSPoint)from delta:(NSPoint)delta forDocument:(MasonDocument *)document
{
    [[document brickView] yaw:delta.x pitch:delta.y];
}

@end
