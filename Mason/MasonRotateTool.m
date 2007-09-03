#import "MasonRotateTool.h"
#import "MasonDocument.h"
#import "MasonBrickView.h"

@implementation MasonRotateTool

- (NSCursor *)activeCursor
{
    return [NSCursor closedHandCursor];
}

- (NSCursor *)inactiveCursor
{
    return [NSCursor openHandCursor];
}

- (void)handleMouseDraggedFrom:(NSPoint)from delta:(NSPoint)delta forDocument:(MasonDocument *)document
{
    [[document brickView] yaw:delta.x pitch:delta.y];
}

@end
