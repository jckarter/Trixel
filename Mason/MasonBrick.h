#include <GL/glew.h>
#import <Cocoa/Cocoa.h>
#include "trixel.h"


@interface MasonBrick : NSObject
{
    trixel_brick * trixelBrick;
}

@property(readonly) NSString * sizeString;
@property(readonly) unsigned width, height, depth;
@property(readonly) struct point3 dimensions;
@property(readonly) trixel_brick * trixelBrick;

- (MasonBrick *)initWithData:(NSData *)data withError:(NSError **)out_error;
- (MasonBrick *)initWithContentsOfFile:(NSString *)filename withError:(NSError **)out_error;
- (MasonBrick *)initSolidWithWidth:(int)width height:(int)height depth:(int)depth withError:(NSError **)out_error;
- (MasonBrick *)initEmptyWithWidth:(int)width height:(int)height depth:(int)depth withError:(NSError **)out_error;

- (MasonBrick *)copyWithZone:(NSZone *)zone;

- (NSData *)data;

- (BOOL)isPrepared;
- (void)prepare;
- (void)unprepare;
- (void)updateTextures;

- (void)draw:(trixel_state)t;
- (void)useForDrawing:(trixel_state)t;

- (unsigned int)countOfPaletteColors;
- (NSColor *)objectInPaletteColorsAtIndex:(unsigned int)index;
- (void)insertObject:(NSColor *)color inPaletteColorsAtIndex:(unsigned int)index;
- (void)removeObjectFromPaletteColorsAtIndex:(unsigned int)index;
- (void)replaceObjectInPaletteColorsAtIndex:(unsigned int)index withObject:(NSColor *)color;

- (NSData *)voxmap;
- (unsigned)voxelX:(unsigned)x y:(unsigned)y z:(unsigned)z;
- (void)setVoxel:(unsigned)index x:(unsigned)x y:(unsigned)y z:(unsigned)z;

- (MasonBrick *)resizedToWidth:(unsigned)width height:(unsigned)height depth:(unsigned)depth;
- (MasonBrick *)shifted:(struct point3)distance;
- (MasonBrick *)mirrored:(struct point3)axis;
- (MasonBrick *)flipped:(struct point3)axis;

@end
