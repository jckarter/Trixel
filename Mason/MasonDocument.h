#import <Cocoa/Cocoa.h>

#include "trixel.h"

@class MasonBrickView;

@interface MasonDocument : NSDocument
{
    IBOutlet NSSegmentedControl * o_sliceAxisSelector;
    IBOutlet MasonBrickView * o_brickView;
    IBOutlet NSTableView *o_paletteTableView;
    IBOutlet NSArrayController *o_paletteController;
    trixel_brick * m_brick;
    
    unsigned int m_currentPaletteColor;
}

- (trixel_brick *)brick;
- (NSString *)brickSizeString;

- (MasonBrickView *)brickView;

- (unsigned int)countOfPaletteColors;
- (NSColor *)objectInPaletteColorsAtIndex:(unsigned int)index;
- (void)insertObject:(NSColor *)color inPaletteColorsAtIndex:(unsigned int)index;
- (void)removeObjectFromPaletteColorsAtIndex:(unsigned int)index;
- (void)replaceObjectInPaletteColorsAtIndex:(unsigned int)index withObject:(NSColor *)color;

- (IBAction)summonColorPanelForPalette:(id)sender;
- (IBAction)updatePaletteColorFromPanel:(id)sender;

- (unsigned int)currentPaletteColor;

// private
- (trixel_brick *)_read_default_brick;
- (void)_replace_brick:(trixel_brick *)new_brick;
@end

#define SLICE_AXIS_SURFACE 0
#define SLICE_AXIS_XAXIS   1
#define SLICE_AXIS_YAXIS   2
#define SLICE_AXIS_ZAXIS   3

