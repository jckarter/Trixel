#import "MasonBrick.h"

NSString *TrixelErrorDomain = @"TrixelErrorDomain";

static NSError *
nserror_from_trixel_error(char *cstring)
{
    NSString *string = [NSString stringWithUTF8String:cstring],
             *first_line, *rest;
    free(cstring); //// frees trixel error string!
    NSRange first_newline = [string rangeOfString:@"\n"];
    if(first_newline.location == NSNotFound) {
        first_line = string;
        rest = nil;
    }
    else {
        first_line = [string substringToIndex:first_newline.location];
        rest = [string substringFromIndex:first_newline.location + first_newline.length];
    }
    
    NSDictionary *errorDict = [NSDictionary dictionaryWithObjectsAndKeys:
        first_line, NSLocalizedDescriptionKey,
        rest, NSLocalizedRecoverySuggestionErrorKey,
        nil
    ];
    
    return [NSError errorWithDomain:TrixelErrorDomain code:0 userInfo:errorDict];
}

static void
_store_nscolor_in_palette(unsigned char * palette_color, NSColor * color)
{
    palette_color[0] = (unsigned char)([color redComponent]   * 255.0);
    palette_color[1] = (unsigned char)([color greenComponent] * 255.0);
    palette_color[2] = (unsigned char)([color blueComponent]  * 255.0);
    palette_color[3] = (unsigned char)([color alphaComponent] * 255.0);    
}

static NSColor *
_nscolor_from_palette(unsigned char * palette_color)
{
    return [NSColor colorWithDeviceRed:(float)palette_color[0]/255.0
                                 green:(float)palette_color[1]/255.0
                                  blue:(float)palette_color[2]/255.0
                                 alpha:(float)palette_color[3]/255.0];
}

@implementation MasonBrick

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
    if([key isEqualToString:@"voxmap"])
        return NO;
    else
        return [super automaticallyNotifiesObserversForKey:key];
}

- (MasonBrick *)initWithData:(NSData *)data withError:(NSError **)out_error
{
    out_error = nil;
    self = [super init];
    if(self) {
        char * error_message;
        m_brick = trixel_read_brick([data bytes], [data length], false, &error_message);
        if(!m_brick) {
            self = nil;
            *out_error = nserror_from_trixel_error(error_message);
        }
    }
    return self;
}

- (MasonBrick *)initWithContentsOfFile:(NSString *)filename withError:(NSError **)out_error
{
    out_error = nil;
    self = [super init];
    if(self) {
        char * error_message;
        m_brick = trixel_read_brick_from_filename([filename UTF8String], false, &error_message);
        if(!m_brick) {
            self = nil;
            *out_error = nserror_from_trixel_error(error_message);
        }
    }
    return self;    
}

- (MasonBrick *)initEmptyWithWidth:(int)width height:(int)height depth:(int)depth withError:(NSError **)out_error
{
    self = [super init];
    if(self) {
        char * error_message;
        m_brick = trixel_make_empty_brick(width, height, depth, false, &error_message);
        if(!m_brick) {
            self = nil;
            *out_error = nserror_from_trixel_error(error_message);
        }
    }
    return self;    
}

- (void)finalize
{
    if(m_brick)
        trixel_only_free_brick(m_brick);
    [super finalize];
}

- (NSData *)data
{
    size_t data_length;
    void * data = trixel_write_brick(m_brick, &data_length);
    
    return [NSData dataWithBytesNoCopy:data length:data_length];
}

- (trixel_brick *)trixel_brick
{
    return m_brick;
}

- (BOOL)isPrepared
{
    return trixel_is_brick_prepared(m_brick);
}

- (void)prepare
{
    trixel_prepare_brick(m_brick);
}

- (void)unprepare
{
    trixel_unprepare_brick(m_brick);
}

- (void)updateTextures
{
    if(trixel_is_brick_prepared(m_brick))
        trixel_update_brick_textures(m_brick);
}

- (void)draw:(trixel_state)t
{
    trixel_draw_brick(t, m_brick);
}

- (void)useForDrawing:(trixel_state)t
{
    trixel_draw_from_brick(t, m_brick);    
}

- (unsigned int)countOfPaletteColors
{
    return 256;
}

- (NSColor *)objectInPaletteColorsAtIndex:(unsigned int)index
{
    //NSLog(@"objectInPaletteColorsAtIndex:%u", index);
    unsigned char *palette_color = trixel_brick_palette_color(m_brick, index);
    return _nscolor_from_palette(palette_color);
}

- (void)insertObject:(NSColor *)color inPaletteColorsAtIndex:(unsigned int)index
{
    //NSLog(@"insertObject:%@ inPaletteColorsAtIndex:%u", color, index);
    if(index == 0)
        return;
    _store_nscolor_in_palette(trixel_insert_brick_palette_color(m_brick, index), color);

    [self updateTextures];
}

- (void)removeObjectFromPaletteColorsAtIndex:(unsigned int)index
{
    //NSLog(@"removeObjectFromPaletteColorsAtIndex:%u", index);
    trixel_remove_brick_palette_color(m_brick, index);
    [self updateTextures];
}

- (void)replaceObjectInPaletteColorsAtIndex:(unsigned int)index withObject:(NSColor *)color
{
    //NSLog(@"replaceObjectInPaletteColorsAtIndex:%u withObject:%@", index, color);

    if(index == 0)
        return;

    unsigned char *palette_color = trixel_brick_palette_color(m_brick, index);
    _store_nscolor_in_palette(palette_color, color);

    [self updateTextures];
}

- (NSData *)voxmap
{
    return [NSData dataWithBytesNoCopy:m_brick->voxmap_data
                                length:trixel_brick_voxmap_size(m_brick)
                          freeWhenDone:NO];
}

- (unsigned)voxelX:(unsigned)x y:(unsigned)y z:(unsigned)z
{
    return *trixel_brick_voxel(m_brick, x, y, z);
}

- (void)setVoxel:(unsigned)index x:(unsigned)x y:(unsigned)y z:(unsigned)z
{
    [self willChangeValueForKey:@"voxmap"];
    
    *trixel_brick_voxel(m_brick, x, y, z) = index;
    [self updateTextures];
    
    [self didChangeValueForKey:@"voxmap"];
}

- (NSString *)sizeString
{
    return [NSString stringWithFormat:@"%ux%ux%u",
        (unsigned)m_brick->dimensions.x,
        (unsigned)m_brick->dimensions.y,
        (unsigned)m_brick->dimensions.z
    ];
}

- (unsigned)width
{
    return (unsigned)m_brick->dimensions.x;
}

- (unsigned)height
{
    return (unsigned)m_brick->dimensions.y;    
}

- (unsigned)depth
{
    return (unsigned)m_brick->dimensions.z;
}

- (struct point3)dimensions
{
    return m_brick->dimensions;
}

@end
