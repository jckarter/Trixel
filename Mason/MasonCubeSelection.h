#include <GL/glew.h>
#import <Cocoa/Cocoa.h>


@interface MasonCubeSelection : NSObject
{
    int minx, miny, minz,
        maxx, maxy, maxz;
}

@property(readwrite) int minx, miny, minz,
                         maxx, maxy, maxz;
@property(readonly) int width, height, depth;

- (void)clipToX:(int)xlimit y:(int)ylimit z:(int)zlimit;

@end
