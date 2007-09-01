#import <Cocoa/Cocoa.h>

@class MasonDocument;

@interface MasonTool : NSObject
{
}

- (NSCursor *)cursor;

- (void)handleMouseDraggedFrom:(NSPoint)from delta:(NSPoint)delta forDocument:(MasonDocument *)document;

@end
