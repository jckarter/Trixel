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

- (void)clipToX:(int)xlimit y:(int)ylimit z:(int)zlimit
{
    if (minx < 0) minx = 0;
    if (miny < 0) miny = 0;
    if (minz < 0) minz = 0;
    if (maxx > xlimit) maxx = xlimit;
    if (maxy > ylimit) maxy = ylimit;
    if (maxz > zlimit) maxz = zlimit;
}

- (MasonCubeSelection *)copyWithZone:(NSZone*)zone
{
    MasonCubeSelection * copy = [[MasonCubeSelection allocWithZone:zone] init];
    copy.minx = minx;
    copy.miny = miny;
    copy.minz = minz;
    copy.maxx = maxx;
    copy.maxy = maxy;
    copy.maxz = maxz;
    
    return copy;
}

@end
