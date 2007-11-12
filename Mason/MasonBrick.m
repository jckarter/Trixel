#import "MasonBrick.h"

NSString *TrixelErrorDomain = @"TrixelErrorDomain";

static inline unsigned umin(unsigned a, unsigned b) { return a < b ? a : b; }
static inline unsigned umax(unsigned a, unsigned b) { return a > b ? a : b; }

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

@interface MasonBrick ()

- (MasonBrick *)_commonInit:(char *)errorMessage :(NSError **)out_error;

@end

@implementation MasonBrick

@synthesize trixelBrick;

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
    if([key isEqualToString:@"voxmap"])
        return NO;
    else
        return [super automaticallyNotifiesObserversForKey:key];
}

- (MasonBrick *)_commonInit:(char *)errorMessage :(NSError **)out_error
{
    if(!trixelBrick) {
        self = nil;
        *out_error = nserror_from_trixel_error(errorMessage);
    }
    return self;
}

- (MasonBrick *)initWithData:(NSData *)data withError:(NSError **)out_error
{
    out_error = nil;
    self = [super init];
    if(self) {
        char * error_message;
        trixelBrick = trixel_read_brick([data bytes], [data length], false, &error_message);
        self = [self _commonInit:error_message :out_error];
    }
    return self;
}

- (MasonBrick *)initWithContentsOfFile:(NSString *)filename withError:(NSError **)out_error
{
    out_error = nil;
    self = [super init];
    if(self) {
        char * error_message;
        trixelBrick = trixel_read_brick_from_filename([filename UTF8String], false, &error_message);
        self = [self _commonInit:error_message :out_error];
    }
    return self;    
}

- (MasonBrick *)initEmptyWithWidth:(int)width height:(int)height depth:(int)depth withError:(NSError **)out_error
{
    self = [super init];
    if(self) {
        char * error_message;
        trixelBrick = trixel_make_empty_brick(width, height, depth, false, &error_message);
        self = [self _commonInit:error_message :out_error];
    }
    return self;    
}

- (void)finalize
{
    if(trixelBrick)
        trixel_only_free_brick(trixelBrick);
    [super finalize];
}

- (NSData *)data
{
    size_t data_length;
    void * data = trixel_write_brick(trixelBrick, &data_length);
    
    return [NSData dataWithBytesNoCopy:data length:data_length];
}

- (BOOL)isPrepared
{
    return trixel_is_brick_prepared(trixelBrick);
}

- (void)prepare
{
    trixel_prepare_brick(trixelBrick);
}

- (void)unprepare
{
    trixel_unprepare_brick(trixelBrick);
}

- (void)updateTextures
{
    if(trixel_is_brick_prepared(trixelBrick))
        trixel_update_brick_textures(trixelBrick);
}

- (void)draw:(trixel_state)t
{
    trixel_draw_brick(t, trixelBrick);
}

- (void)useForDrawing:(trixel_state)t
{
    trixel_draw_from_brick(t, trixelBrick);    
}

- (unsigned int)countOfPaletteColors
{
    return 256;
}

- (NSColor *)objectInPaletteColorsAtIndex:(unsigned int)index
{
    unsigned char *palette_color = trixel_brick_palette_color(trixelBrick, index);
    return _nscolor_from_palette(palette_color);
}

- (void)insertObject:(NSColor *)color inPaletteColorsAtIndex:(unsigned int)index
{
    if(index == 0)
        return;

    _store_nscolor_in_palette(trixel_insert_brick_palette_color(trixelBrick, index), color);

    [self updateTextures];
}

- (void)removeObjectFromPaletteColorsAtIndex:(unsigned int)index
{
    trixel_remove_brick_palette_color(trixelBrick, index);
    [self updateTextures];
}

- (void)replaceObjectInPaletteColorsAtIndex:(unsigned int)index withObject:(NSColor *)color
{
    if(index == 0)
        return;

    unsigned char *palette_color = trixel_brick_palette_color(trixelBrick, index);
    _store_nscolor_in_palette(palette_color, color);

    [self updateTextures];
}

- (NSData *)voxmap
{
    return [NSData dataWithBytesNoCopy:trixelBrick->voxmap_data
                                length:trixel_brick_voxmap_size(trixelBrick)
                          freeWhenDone:NO];
}

- (unsigned)voxelX:(unsigned)x y:(unsigned)y z:(unsigned)z
{
    return *trixel_brick_voxel(trixelBrick, x, y, z);
}

- (void)setVoxel:(unsigned)index x:(unsigned)x y:(unsigned)y z:(unsigned)z
{
    [self willChangeValueForKey:@"voxmap"];
    
    *trixel_brick_voxel(trixelBrick, x, y, z) = index;
    [self updateTextures];
    
    [self didChangeValueForKey:@"voxmap"];
}

- (NSString *)sizeString
{
    return [NSString stringWithFormat:@"%ux%ux%u",
        (unsigned)trixelBrick->dimensions.x,
        (unsigned)trixelBrick->dimensions.y,
        (unsigned)trixelBrick->dimensions.z
    ];
}

- (unsigned)width
{
    return (unsigned)trixelBrick->dimensions.x;
}

- (unsigned)height
{
    return (unsigned)trixelBrick->dimensions.y;    
}

- (unsigned)depth
{
    return (unsigned)trixelBrick->dimensions.z;
}

- (struct point3)dimensions
{
    return trixelBrick->dimensions;
}

- (MasonBrick *)resizedToWidth:(unsigned)width height:(unsigned)height depth:(unsigned)depth;
{
    NSError * error;
    MasonBrick * newBrick = [[MasonBrick alloc] initEmptyWithWidth:width height:height depth:depth withError:&error];
    
    if(newBrick) {
        memcpy(newBrick.trixelBrick->palette_data, self.trixelBrick->palette_data, 256*4);
        
        unsigned copy_width  = umin(self.width,  width ),
                 copy_height = umin(self.height, height),
                 copy_depth  = umin(self.depth,  depth );
        for(unsigned z = 0; z < copy_depth; ++z)
            for(unsigned y = 0; y < copy_height; ++y)
                for(unsigned x = 0; x < copy_width; ++x)
                    *trixel_brick_voxel(newBrick.trixelBrick, x, y, z)
                        = *trixel_brick_voxel(self.trixelBrick, x, y, z);
    }
    return newBrick;
}

@end
