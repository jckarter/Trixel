#import <Cocoa/Cocoa.h>
#include "trixel.h"


@interface MasonBrick : NSObject
{
    trixel_brick * m_brick;
}

- (MasonBrick *)initWithData:(NSData *)data withError:(NSError **)out_error;
- (MasonBrick *)initWithContentsOfFile:(NSString *)filename withError:(NSError **)out_error;

- (NSData *)data;

- (trixel_brick *)trixel_brick;

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

- (NSString *)sizeString;

@end
