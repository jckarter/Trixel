#import <Cocoa/Cocoa.h>
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

- (void)handleMouseDraggedFrom:(NSPoint)from delta:(NSPoint)delta forDocument:(MasonDocument *)document
{
    // do nothing
}

@end

