#import "MasonEraseTool.h"
#import "MasonDocument.h"
#import "MasonBrickView.h"
#import "MasonBrick.h"

#include "trixel.h"

@implementation MasonEraseTool

- (NSCursor *)inactiveCursor
{
    return [NSCursor crosshairCursor];
}

- (void)handleMouseDraggedFrom:(NSPoint)from delta:(NSPoint)delta forDocument:(MasonDocument *)document
{
    struct point3 hoverPoint = [[document brickView] hoverPoint];
    if(hoverPoint.x >= 0.0)
        [[document brick] setVoxel:[document currentPaletteColor]
                          x:hoverPoint.x y:hoverPoint.y z:hoverPoint.z];
}

@end
