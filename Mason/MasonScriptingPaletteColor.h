#import <Cocoa/Cocoa.h>


@interface MasonScriptingPaletteColor : NSObject
{
    id scriptingContainer;
    NSUInteger index;
    float redComponent, greenComponent, blueComponent, alphaComponent;
}

@property float redComponent, greenComponent, blueComponent, alphaComponent;

- (MasonScriptingPaletteColor *)initWithScriptingContainer:(id)cont
                                                     index:(NSUInteger)idx
                                              redComponent:(float)red
                                            greenComponent:(float)green
                                             blueComponent:(float)blue
                                            alphaComponent:(float)alpha;

@end
