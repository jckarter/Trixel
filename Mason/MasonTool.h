#include <GL/glew.h>
#import <Cocoa/Cocoa.h>

@class MasonDocument;

typedef enum {
    MasonUnitNone,
    MasonUnitVoxel,
    MasonUnitFace
} MasonUnit;

@interface MasonTool : NSObject
{
}

- (BOOL)isDestructive;

- (MasonUnit)unit;

- (NSCursor *)activeCursor;
- (NSCursor *)inactiveCursor;

- (void)handleMouseDraggedFrom:(NSPoint)from delta:(NSPoint)delta forDocument:(MasonDocument *)document;

@end
