#include <GL/glew.h>
#import <Cocoa/Cocoa.h>
#include "trixel.h"


@class MasonBrickView;
@class MasonBrick;

@interface MasonDocument : NSDocument
{
    IBOutlet NSSegmentedControl * o_sliceAxisSelector;
    IBOutlet MasonBrickView * o_brickView;
    IBOutlet NSTableView *o_paletteTableView;
    IBOutlet NSArrayController *o_paletteController;
    
    MasonBrick * m_brick;
    unsigned int m_currentPaletteColor;
}

- (MasonBrick *)brick;
- (void)setBrick:(MasonBrick *)brick;

- (MasonBrickView *)brickView;

- (IBAction)summonColorPanelForPalette:(id)sender;
- (IBAction)updatePaletteColorFromPanel:(id)sender;

- (unsigned int)currentPaletteColor;
- (void)updatePaletteIndex:(unsigned)index withColor:(NSColor *)color;

- (void)setBrickVoxel:(unsigned int)index at:(struct point3)pt;

// private
- (MasonBrick *)_default_brick;

@end

#define SLICE_AXIS_SURFACE 0
#define SLICE_AXIS_XAXIS   1
#define SLICE_AXIS_YAXIS   2
#define SLICE_AXIS_ZAXIS   3

