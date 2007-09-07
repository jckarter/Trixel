#import "MasonDocument.h"
#import "MasonColorCell.h"
#include <stdlib.h>

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

static void
_update_voxmap_colors(trixel_brick * brick, int minIndex, int offset)
{
    size_t voxmap_size = trixel_brick_voxmap_size(brick);
    for(size_t i = 0; i < voxmap_size; ++i)
        if(brick->voxmap_data[i] >= minIndex)
            brick->voxmap_data[i] += offset;
}

@implementation MasonDocument

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
    if([key isEqualToString:@"brickSizeString"])
        return NO;
    else
        return [super automaticallyNotifiesObserversForKey:key];
}

- (id)init
{
    self = [super init];
    if(self) {
        [self _read_default_brick];
    }
    return self;
}

- (void)dealloc
{
    if(m_brick) {
        trixel_free_brick(m_brick);
    }
    [super dealloc];
}

- (NSString *)windowNibName
{
    return @"MasonDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];
        
    for(int i = 0; i < [o_sliceAxisSelector segmentCount]; ++i)
        [o_sliceAxisSelector setLabel:nil forSegment:i];
    [o_sliceAxisSelector selectSegmentWithTag:SLICE_AXIS_SURFACE];
    
    NSTableColumn * paletteColumn = [[o_paletteTableView tableColumns] objectAtIndex:0];
    MasonColorCell * colorCell = [[[MasonColorCell alloc] init] autorelease];
    [colorCell setEditable:YES];
    [colorCell setTarget:self];
    [colorCell setAction:@selector(summonColorPanelForPalette:)];
    [paletteColumn setDataCell:colorCell];
}

- (IBAction)summonColorPanelForPalette:(id)sender
{
    NSColorPanel * colorPanel = [NSColorPanel sharedColorPanel];
    m_currentPaletteColor = [sender clickedRow];
    [colorPanel setTarget:self];
    [colorPanel setAction:@selector(updatePaletteColorFromPanel:)];
	[colorPanel setShowsAlpha:YES];
	[colorPanel setColor:[self objectInPaletteColorsAtIndex:m_currentPaletteColor]];
	[colorPanel makeKeyAndOrderFront:self];
    [o_paletteController setSelectionIndex:m_currentPaletteColor];
}

- (IBAction)updatePaletteColorFromPanel:(id)sender
{
    [self replaceObjectInPaletteColorsAtIndex:m_currentPaletteColor withObject:[sender color]];
}

- (unsigned int)currentPaletteColor
{
    return m_currentPaletteColor;
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)out_error
{
    return nil;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)out_error
{
    char * error_message;

    trixel_brick * new_brick = trixel_read_brick((void *)[data bytes], [data length], false, &error_message);
    
    if(!new_brick) {
        *out_error = nserror_from_trixel_error(error_message);
        return NO;
    }
    
    [self _replace_brick:new_brick];
    return YES;
}

- (trixel_brick *)brick
{
    return m_brick;
}

- (NSString *)brickSizeString
{
    return [NSString stringWithFormat:@"%ux%ux%u",
        (unsigned)m_brick->dimensions[0],
        (unsigned)m_brick->dimensions[1],
        (unsigned)m_brick->dimensions[2]
    ];
}

- (MasonBrickView *)brickView
{
    return o_brickView;
}

- (unsigned int)countOfPaletteColors
{
    return 256;
}

- (NSColor *)objectInPaletteColorsAtIndex:(unsigned int)index
{
    unsigned char *palette_color = trixel_brick_palette_color(m_brick, index);
    return _nscolor_from_palette(palette_color);
}

- (void)insertObject:(NSColor *)color inPaletteColorsAtIndex:(unsigned int)index
{
    unsigned char * palette_color = trixel_brick_palette_color(m_brick, index),
                  * next_palette_color = palette_color + 4;
    memmove(next_palette_color, palette_color, (256 - index - 1) * 4);
    _store_nscolor_in_palette(palette_color, color);
    _update_voxmap_colors(m_brick, index + 1, 1);
    
    if(trixel_is_brick_prepared(m_brick))
        trixel_update_brick_textures(m_brick);
    [o_brickView setNeedsDisplay:YES];
}

- (void)removeObjectFromPaletteColorsAtIndex:(unsigned int)index
{
    unsigned char * palette_color = trixel_brick_palette_color(m_brick, index),
                  * next_palette_color = palette_color + 4;
    memmove(palette_color, next_palette_color, (256 - index - 1) * 4);
    memset(trixel_brick_palette_color(m_brick, 255), 0, 4);
    _update_voxmap_colors(m_brick, index + 1, -1);
    
    if(trixel_is_brick_prepared(m_brick))
        trixel_update_brick_textures(m_brick);
    [o_brickView setNeedsDisplay:YES];
}

- (void)replaceObjectInPaletteColorsAtIndex:(unsigned int)index withObject:(NSColor *)color
{
    unsigned char *palette_color = trixel_brick_palette_color(m_brick, index);
    _store_nscolor_in_palette(palette_color, color);
    if(trixel_is_brick_prepared(m_brick))
        trixel_update_brick_textures(m_brick);
    [o_brickView setNeedsDisplay:YES];
}

- (trixel_brick *)_read_default_brick
{
    char * error_message;
    m_brick = trixel_read_brick_from_filename(
        [[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"default.brick"] UTF8String],
        false, &error_message
    );
    return m_brick;
}

- (void)_replace_brick:(trixel_brick *)new_brick
{
    [self willChangeValueForKey:@"brickSizeString"];
    if(m_brick)
        trixel_free_brick(m_brick);
    m_brick = new_brick;
    [self didChangeValueForKey:@"brickSizeString"];        
}

@end
