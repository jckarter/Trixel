#include <GL/glew.h>
#include "trixel.h"
#import "MasonGetVoxelCommand.h"
#import "MasonDocument.h"
#import "MasonBrick.h"
#import "MasonScriptingSupport.h"

@implementation MasonGetVoxelCommand

- (id)performDefaultImplementation
{
    NSDictionary * args = [self evaluatedArguments];
    
    id brick = [args objectForKey:@"Brick"];
    
    if([brick respondsToSelector:@selector(brick)])
        brick = [brick brick];
    
    struct point3 point = point3_from_nsdictionary([args objectForKey:@"Point"]);
    
    return [NSNumber numberWithUnsignedInteger:[brick voxelX:point.x y:point.y z:point.z]];
}

@end
