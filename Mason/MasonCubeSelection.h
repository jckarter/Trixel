#include <GL/glew.h>
#import <Cocoa/Cocoa.h>


@interface MasonCubeSelection : NSObject
{
    int minx, miny, minz,
        maxx, maxy, maxz;
}

@property(readwrite) int minx, miny, minz,
                         maxx, maxy, maxz;

@end
