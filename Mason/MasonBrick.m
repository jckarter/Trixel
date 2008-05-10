#import "MasonBrick.h"
#import "MasonScriptingPaletteColor.h"
#import "MasonDocument.h"
#import "MasonCubeSelection.h"

NSString *TrixelErrorDomain = @"TrixelErrorDomain";

static inline unsigned umin(unsigned a, unsigned b) { return a < b ? a : b; }
static inline unsigned umax(unsigned a, unsigned b) { return a > b ? a : b; }

static inline float clamp_neg(float a) { return a < 0 ? 0 : a; }
static inline float clamp_pos(float a) { return a > 0 ? 0 : a; }

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
_store_color_in_palette(unsigned char * palette_color, id color)
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

static MasonScriptingPaletteColor *
_scripting_color_from_palette(unsigned char * palette_color, id cont, unsigned index)
{
    return [[MasonScriptingPaletteColor alloc] initWithScriptingContainer:cont
                                                                    index:index
                                                             redComponent:(float)palette_color[0]/255.0
                                                           greenComponent:(float)palette_color[1]/255.0
                                                            blueComponent:(float)palette_color[2]/255.0
                                                           alphaComponent:(float)palette_color[3]/255.0];
}

static void
_copy_brick_slice(trixel_brick * brick, int sliceAxis, int sliceNumber, int destSliceNumber)
{
    int upitch, vpitch, wpitch, ucount, vcount;
    if(sliceAxis == SLICE_AXIS_XAXIS) {
        upitch = brick->dimensions.x;
        vpitch = brick->dimensions.x * brick->dimensions.y;
        wpitch = 1;
        ucount = brick->dimensions.y;
        vcount = brick->dimensions.z;
    }
    else if(sliceAxis == SLICE_AXIS_YAXIS) {
        upitch = 1;
        vpitch = brick->dimensions.x * brick->dimensions.y;
        wpitch = brick->dimensions.x;
        ucount = brick->dimensions.x;
        vcount = brick->dimensions.z;
    }
    else if(sliceAxis == SLICE_AXIS_ZAXIS) {
        upitch = 1;
        vpitch = brick->dimensions.x;
        wpitch = brick->dimensions.x * brick->dimensions.y;
        ucount = brick->dimensions.x;
        vcount = brick->dimensions.y;
    }
    
    unsigned char * from = brick->voxmap_data + wpitch * sliceNumber,
                  * to   = brick->voxmap_data + wpitch * destSliceNumber;
    for(int v = 0; v < vcount; ++v)
        for(int u = 0; u < ucount; ++u)
            to[u * upitch + v * vpitch] = from[u * upitch + v * vpitch];
}

@interface MasonBrick ()

- (MasonBrick *)_commonInit:(char *)errorMessage :(NSError **)out_error;

- (unsigned int)countOfScriptingPaletteColors;
- (MasonScriptingPaletteColor *)objectInScriptingPaletteColorsAtIndex:(unsigned int)index;
- (void)insertObject:(MasonScriptingPaletteColor *)color inScriptingPaletteColorsAtIndex:(unsigned int)index;
- (void)removeObjectFromScriptingPaletteColorsAtIndex:(unsigned int)index;
- (void)replaceObjectInScriptingPaletteColorsAtIndex:(unsigned int)index withObject:(MasonScriptingPaletteColor *)color;

@end

@implementation MasonBrick

@synthesize trixelBrick, scriptingContainer;

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
    if([key isEqualToString:@"voxmap"])
        return NO;
    else
        return [super automaticallyNotifiesObserversForKey:key];
}

+ (void)initialize
{
    [self setKeys:[NSArray arrayWithObjects:@"scriptingPaletteColors", nil]
          triggerChangeNotificationsForDependentKey:@"paletteColors"];
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
        trixelBrick = trixel_read_brick([data bytes], [data length], &error_message);
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
        trixelBrick = trixel_read_brick_from_filename([filename UTF8String], &error_message);
        self = [self _commonInit:error_message :out_error];
    }
    return self;    
}

- (MasonBrick *)initSolidWithWidth:(int)width height:(int)height depth:(int)depth withError:(NSError **)out_error
{
    self = [super init];
    if(self) {
        char * error_message;
        trixelBrick = trixel_make_solid_brick(width, height, depth, &error_message);
        self = [self _commonInit:error_message :out_error];
    }
    return self;    
}

- (MasonBrick *)initEmptyWithWidth:(int)width height:(int)height depth:(int)depth withError:(NSError **)out_error
{
    self = [super init];
    if(self) {
        char * error_message;
        trixelBrick = trixel_make_empty_brick(width, height, depth, &error_message);
        self = [self _commonInit:error_message :out_error];
    }
    return self;    
}

- (MasonBrick *)copyWithZone:(NSZone *)zone
{
    MasonBrick * copy = [[MasonBrick allocWithZone:zone] init];
    if(copy) {
        char * error_message;
        NSError * error;
        copy->trixelBrick = trixel_copy_brick(self.trixelBrick, &error_message);
        
        copy = [copy _commonInit:error_message :&error];
    }
    return copy;
}

- (void)finalize
{
    if(trixelBrick)
        trixel_only_free_brick(trixelBrick);
    scriptingContainer = nil;
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

- (void)prepare:(trixel_state)t
{
    trixel_prepare_brick(trixelBrick, t);
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

- (void)draw
{
    trixel_draw_brick(trixelBrick);
}

- (void)useForDrawing
{
    trixel_draw_from_brick(trixelBrick);    
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

    _store_color_in_palette(trixel_insert_brick_palette_color(trixelBrick, index), color);

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
    _store_color_in_palette(palette_color, color);

    [self updateTextures];
}

- (unsigned int)countOfScriptingPaletteColors
{
    return 256;
}

- (MasonScriptingPaletteColor *)objectInScriptingPaletteColorsAtIndex:(unsigned int)index
{
    unsigned char *palette_color = trixel_brick_palette_color(trixelBrick, index);
    return _scripting_color_from_palette(palette_color, self, index);
}

- (void)insertObject:(MasonScriptingPaletteColor *)color inScriptingPaletteColorsAtIndex:(unsigned int)index
{
    if(index == 0)
        return;

    _store_color_in_palette(trixel_insert_brick_palette_color(trixelBrick, index), color);

    [self updateTextures];
}

- (void)removeObjectFromScriptingPaletteColorsAtIndex:(unsigned int)index
{
    trixel_remove_brick_palette_color(trixelBrick, index);
    [self updateTextures];
}

- (void)replaceObjectInScriptingPaletteColorsAtIndex:(unsigned int)index withObject:(MasonScriptingPaletteColor *)color
{
    if(index == 0)
        return;

    unsigned char *palette_color = trixel_brick_palette_color(trixelBrick, index);
    _store_color_in_palette(palette_color, color);

    [self updateTextures];
}

- (NSScriptObjectSpecifier *)objectSpecifier
{
    return [[NSPropertySpecifier alloc] initWithContainerSpecifier:[scriptingContainer objectSpecifier]
                                                               key:@"brick"];
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

- (MasonBrick *)shiftingSelectedArea:(MasonCubeSelection *)selection distance:(struct point3)distance
{
    MasonBrick * selectedArea = [self selectedArea:selection];
    
    MasonCubeSelection * oldSelection = [selection copy];
    selection.minx += distance.x;
    selection.miny += distance.y;
    selection.minz += distance.z;
    selection.maxx += distance.x;
    selection.maxy += distance.y;
    selection.maxz += distance.z;
    
    MasonBrick * newBrick = [[self clearingSelectedArea:oldSelection] replacingSelectedArea:selection withBrick:selectedArea];
    [selection clipToX:self.width y:self.height z:self.depth];
    return newBrick;
}

- (MasonBrick *)flippingSelectedArea:(MasonCubeSelection *)selection acrossAxis:(struct point3)axis
{
    MasonBrick * newBrick = [self copy];
    
    if(newBrick) {
        unsigned char * to = trixel_brick_voxel(
                                 newBrick.trixelBrick, 
                                 (axis.x ? selection.maxx-1 : selection.minx),
                                 (axis.y ? selection.maxy-1 : selection.miny),
                                 (axis.z ? selection.maxz-1 : selection.minz)
                             );
        int xpitch = axis.x ? -1 : 1;
        int ypitch = axis.y ? -self.width : self.width;
        int zpitch = axis.z ? -self.width * self.height : self.width * self.height;
        
        for(unsigned z = 0; z < selection.depth; ++z)
            for(unsigned y = 0; y < selection.height; ++y)
                for(unsigned x = 0; x < selection.width; ++x)
                    to[xpitch * x + ypitch * y + zpitch * z] = *trixel_brick_voxel(
                        self.trixelBrick,
                        x+selection.minx,
                        y+selection.miny,
                        z+selection.minz
                    );
    }
    return newBrick;
}

- (MasonBrick *)mirroringSelectedArea:(MasonCubeSelection *)selection acrossAxis:(struct point3)axis
{
    MasonBrick * newBrick = [self copy];
    
    if(newBrick) {
        unsigned from_x = (axis.x > 0 ? selection.maxx-1 : selection.minx),
                 from_y = (axis.y > 0 ? selection.maxy-1 : selection.miny),
                 from_z = (axis.z > 0 ? selection.maxz-1 : selection.minz);
        
        unsigned to_x = (axis.x ? selection.maxx-1 - (from_x - selection.minx) : from_x),
                 to_y = (axis.y ? selection.maxy-1 - (from_y - selection.miny) : from_y),
                 to_z = (axis.z ? selection.maxz-1 - (from_z - selection.minz) : from_z);
    
        unsigned char * from = trixel_brick_voxel(
                                   newBrick.trixelBrick,
                                   from_x, from_y, from_z
                               ),
                      * to   = trixel_brick_voxel(
                                   newBrick.trixelBrick,
                                   to_x, to_y, to_z
                               );
        int copy_width  = axis.x ? selection.width /2 : selection.width ,
            copy_height = axis.y ? selection.height/2 : selection.height,
            copy_depth  = axis.z ? selection.depth /2 : selection.depth ;

        int from_xpitch = axis.x > 0 ? -1                        : 1,
            from_ypitch = axis.y > 0 ? -self.width               : self.width,
            from_zpitch = axis.z > 0 ? -self.width * self.height : self.width * self.height;
        
        int to_xpitch = axis.x ? -from_xpitch : from_xpitch,
            to_ypitch = axis.y ? -from_ypitch : from_ypitch,
            to_zpitch = axis.z ? -from_zpitch : from_zpitch;
        
        for(unsigned z = 0; z < copy_depth; ++z)
            for(unsigned y = 0; y < copy_height; ++y)
                for(unsigned x = 0; x < copy_width; ++x)
                    to[to_xpitch * x + to_ypitch * y + to_zpitch * z]
                        = from[from_xpitch * x + from_ypitch * y + from_zpitch * z];
    }
    return newBrick;
}

- (MasonBrick *)selectedArea:(MasonCubeSelection *)selection
{
    NSError * error;
    MasonBrick * newBrick = [[MasonBrick alloc] initEmptyWithWidth:selection.width
                                                height:selection.height
                                                depth:selection.depth
                                                withError:&error];
    
    if(newBrick) {
        memcpy(newBrick.trixelBrick->palette_data, self.trixelBrick->palette_data, 256*4);
    
        for(unsigned z = selection.minz; z < selection.maxz; ++z)
            for(unsigned y = selection.miny; y < selection.maxy; ++y)
                for(unsigned x = selection.minx; x < selection.maxx; ++x)
                    *trixel_brick_voxel(
                        newBrick.trixelBrick,
                        x - selection.minx,
                        y - selection.miny,
                        z - selection.minz
                    ) = *trixel_brick_voxel(self.trixelBrick, x, y, z);
    }
    return newBrick;
}

- (MasonBrick *)replacingSelectedArea:(MasonCubeSelection *)selection withBrick:(MasonBrick *)subbrick
{
    MasonCubeSelection * clippedSelection = [selection copy];
    [clippedSelection clipToX:self.width y:self.height z:self.depth];
    
    MasonBrick * newBrick = [self copy];
    
    for(unsigned z = clippedSelection.minz; z < clippedSelection.maxz; ++z)
        for(unsigned y = clippedSelection.miny; y < clippedSelection.maxy; ++y)
            for(unsigned x = clippedSelection.minx; x < clippedSelection.maxx; ++x)
                    *trixel_brick_voxel(newBrick.trixelBrick, x, y, z) = *trixel_brick_voxel(
                        subbrick.trixelBrick,
                        x - selection.minx,
                        y - selection.miny,
                        z - selection.minz
                    );
    return newBrick;
}

- (MasonBrick *)clearingSelectedArea:(MasonCubeSelection *)selection
{
    MasonBrick * newBrick = [self copy];

    for(unsigned z = selection.minz; z < selection.maxz; ++z)
        for(unsigned y = selection.miny; y < selection.maxy; ++y)
            for(unsigned x = selection.minx; x < selection.maxx; ++x)
                    *trixel_brick_voxel(newBrick.trixelBrick, x, y, z) = 0;
    return newBrick;
}

- (MasonBrick *)brickWithSliceAxis:(NSInteger)sliceAxis
                sliceNumber:(NSInteger)sliceNumber
                copiedToSliceNumber:(NSInteger)destSliceNumber
{
    MasonBrick * newBrick = [self copy];
    
    _copy_brick_slice(newBrick.trixelBrick, sliceAxis, sliceNumber, destSliceNumber);
    
    return newBrick;
}

- (MasonBrick *)brickWithSliceAxis:(NSInteger)sliceAxis
                sliceNumberProjected:(NSInteger)sliceNumber
{
    MasonBrick * newBrick = [self copy];
    int sliceCount = (sliceAxis == SLICE_AXIS_XAXIS
        ? [self width]  : sliceAxis == SLICE_AXIS_YAXIS
        ? [self height]
        : [self depth]);
    
    for(int i = 0; i < sliceCount; ++i)
        if(i == sliceNumber)
            continue;
        else
            _copy_brick_slice(newBrick.trixelBrick, sliceAxis, sliceNumber, i);
    return newBrick;
}

@end
