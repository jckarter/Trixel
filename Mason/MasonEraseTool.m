#import "MasonEraseTool.h"
#import "MasonDocument.h"
#import "MasonBrickView.h"
#import "MasonBrick.h"

#include "trixel.h"

@implementation MasonEraseTool

- (BOOL)isDestructive
{
    return YES;
}

- (NSCursor *)inactiveCursor
{
    return [NSCursor crosshairCursor];
}

- (void)handleMouseDraggedFrom:(NSPoint)from delta:(NSPoint)delta forDocument:(MasonDocument *)document
{
    struct point3 hoverPoint = [[document brickView] hoverPoint];
    if(hoverPoint.x == -1) return;
    [document setBrickVoxel:0 at:hoverPoint];
}

@end
