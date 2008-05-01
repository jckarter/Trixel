#import "MasonLowSelectionTool.h"
#import "MasonDocument.h"
#import "MasonBrickView.h"
#import "MasonBrick.h"

#include "trixel.h"

@implementation MasonLowSelectionTool

- (BOOL)isDestructive
{
    return NO;
}

- (NSCursor *)inactiveCursor
{
    return [NSCursor crosshairCursor];
}

- (MasonUnit)unit
{
    return MasonUnitVoxel;
}

- (void)handleMouseDraggedFrom:(NSPoint)from delta:(NSPoint)delta forDocument:(MasonDocument *)document
{
    struct point3 hoverPoint = [[document brickView] hoverPoint];
    if(hoverPoint.x == -1) return;
    [document setLowSelectionPoint:hoverPoint];
}

@end
