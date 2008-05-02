#import "MasonCubeSelection.h"

@implementation MasonCubeSelection

@synthesize minx, miny, minz,
            maxx, maxy, maxz;

- (void)setMinx:(int)x
{
    minx = x;
    if (maxx <= minx)
        maxx = minx + 1;
}

- (void)setMiny:(int)y
{
    miny = y;
    if (maxy <= miny)
        maxy = miny + 1;
}

- (void)setMinz:(int)z
{
    minz = z;
    if (maxz <= minz)
        maxz = minz + 1;
}

- (int)width
{
    return maxx - minx;
}

- (int)height
{
    return maxy - miny;
}

- (int)depth
{
    return maxz - minz;
}

@end
