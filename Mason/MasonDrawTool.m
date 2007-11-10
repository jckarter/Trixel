#import "MasonDrawTool.h"
#import "MasonDocument.h"
#import "MasonBrickView.h"
#import "MasonBrick.h"

#include "trixel.h"

@implementation MasonDrawTool

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
    [document setBrickVoxel:[document currentPaletteColor] at:hoverPoint];
}

@end
