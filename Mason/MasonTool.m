#import "MasonTool.h"
#import "MasonDocument.h"

@implementation MasonTool

- (NSCursor *)activeCursor
{
    return [self inactiveCursor];
}

- (NSCursor *)inactiveCursor
{
    return [NSCursor arrowCursor];
}

- (BOOL)isDestructive
{
    return NO;
}

- (MasonUnit)unit
{
    return MasonUnitNone;
}

- (void)handleMouseDraggedFrom:(NSPoint)from delta:(NSPoint)delta forDocument:(MasonDocument *)document
{
    // do nothing
}

- (NSDrawer *)settingsDrawer
{
    return nil;
}

@end

