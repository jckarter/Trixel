#import <Cocoa/Cocoa.h>
#import "MasonTool.h"
#import "MasonDocument.h"

@implementation MasonTool

- (NSCursor *)cursor
{
    return [NSCursor arrowCursor];
}

- (void)handleMouseDraggedFrom:(NSPoint)from delta:(NSPoint)delta forDocument:(MasonDocument *)document
{
    // do nothing
}

@end

