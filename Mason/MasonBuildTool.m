#import "MasonBuildTool.h"
#import "MasonDocument.h"
#import "MasonBrickView.h"
#import "MasonBrick.h"

#include "trixel.h"

@implementation MasonBuildTool

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
    struct point3 hoverPoint = [[document brickView] hoverPoint],
                  buildPoint = add_point3(hoverPoint, [[document brickView] hoverNormal]);
    
    if(hoverPoint.x == -1) return;

    [document setBrickVoxel:[document currentPaletteColor] 
        at:in_point3([[document brick] dimensions], buildPoint)
            ? buildPoint
            : hoverPoint];
}

@end
