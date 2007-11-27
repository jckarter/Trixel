#import "MasonScriptingSupport.h"

struct point3
point3_from_nsdictionary(NSDictionary * dict)
{
    return POINT3([[dict objectForKey:@"xCoordinate"] floatValue],
                  [[dict objectForKey:@"yCoordinate"] floatValue],
                  [[dict objectForKey:@"zCoordinate"] floatValue]);
}

