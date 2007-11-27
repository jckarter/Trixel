#import "MasonScriptingPaletteColor.h"


@implementation MasonScriptingPaletteColor

@synthesize redComponent, greenComponent, blueComponent, alphaComponent;

- (MasonScriptingPaletteColor *)initWithScriptingContainer:(id)cont
                                                     index:(NSUInteger)idx
                                              redComponent:(float)red
                                            greenComponent:(float)green
                                             blueComponent:(float)blue
                                            alphaComponent:(float)alpha;
{
    self = [super init];
    if(self) {
        scriptingContainer = cont;
        index = idx;
        redComponent = red;
        greenComponent = green;
        blueComponent = blue;
        alphaComponent = alpha;
    }
    return self;
}

- (NSScriptObjectSpecifier *)objectSpecifier
{
    return [[NSIndexSpecifier alloc] initWithContainerClassDescription:[NSScriptClassDescription classDescriptionForClass:[scriptingContainer class]]
                                                    containerSpecifier:[scriptingContainer objectSpecifier]
                                                                   key:@"scriptingPaletteColors"
                                                                 index:index];
}

@end
