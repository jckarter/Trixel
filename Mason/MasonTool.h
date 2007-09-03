#import <Cocoa/Cocoa.h>

@class MasonDocument;

@interface MasonTool : NSObject
{
}

- (NSCursor *)activeCursor;
- (NSCursor *)inactiveCursor;

- (void)handleMouseDraggedFrom:(NSPoint)from delta:(NSPoint)delta forDocument:(MasonDocument *)document;

@end
