#include <GL/glew.h>
#include "trixel.h"
#import "MasonSetVoxelCommand.h"
#import "MasonDocument.h"
#import "MasonBrick.h"
#import "MasonScriptingSupport.h"

@implementation MasonSetVoxelCommand

- (id)performDefaultImplementation
{
    NSDictionary * args = [self evaluatedArguments];
    
    id brick = [args objectForKey:@"Brick"];
    struct point3 point = point3_from_nsdictionary([args objectForKey:@"Point"]);
    NSUInteger color = [[args objectForKey:@"Color"] unsignedIntegerValue];

    if([brick respondsToSelector:@selector(brick)])
        brick = [brick brick];
    
    [brick setVoxel:color x:point.x y:point.y z:point.z];
    return nil;
}

@end
