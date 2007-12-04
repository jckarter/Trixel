#import "MasonPushTool.h"
#import "MasonDocument.h"
#import "MasonBrickView.h"
#import "MasonBrick.h"

#include "trixel.h"

@implementation MasonPushTool

- (BOOL)isDestructive
{
    return YES;
}

- (NSCursor *)inactiveCursor
{
    return [NSCursor crosshairCursor];
}

- (MasonUnit)unit
{
    return MasonUnitFace;
}

- (void)handleMouseDraggedFrom:(NSPoint)from delta:(NSPoint)delta forDocument:(MasonDocument *)document
{
    struct point3 hoverPoint = [[document brickView] hoverPoint],
                  pushPoint = sub_point3(hoverPoint, [[document brickView] hoverNormal]);
    
    if(hoverPoint.x == -1) return;
    
    if(in_point3([[document brick] dimensions], pushPoint)) {
        [document setBrickVoxel:[document brickVoxelAt:hoverPoint] at:pushPoint];
        [document setBrickVoxel:0                                  at:hoverPoint];
    }
}

@end
