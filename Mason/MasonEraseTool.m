#import "MasonEraseTool.h"
#import "MasonDocument.h"
#import "MasonBrickView.h"

#include "trixel.h"

@implementation MasonEraseTool

- (NSCursor *)inactiveCursor
{
    return [NSCursor crosshairCursor];
}

- (void)handleMouseDraggedFrom:(NSPoint)from delta:(NSPoint)delta forDocument:(MasonDocument *)document
{
    struct point3 hoverPoint = [[document brickView] hoverPoint];
    
    if(hoverPoint.x >= 0.0) {
        *(trixel_brick_voxel([document brick], hoverPoint.x, hoverPoint.y, hoverPoint.z)) = 0;
    }
    trixel_update_brick_textures([document brick]);
}

@end
