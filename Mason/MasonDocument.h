#include <GL/glew.h>
#import <Cocoa/Cocoa.h>
#include "trixel.h"


@class MasonBrickView;
@class MasonBrick;

@interface MasonDocument : NSDocument
{
    IBOutlet NSSegmentedControl * o_sliceAxisSelector, *o_sliceMover;
    IBOutlet MasonBrickView * o_brickView;
    IBOutlet NSTableView *o_paletteTableView;
    IBOutlet NSArrayController *o_paletteController;
    
    MasonBrick * m_brick;
    NSUInteger m_currentPaletteColor;
    NSInteger m_sliceAxis, m_sliceNumber;
}

- (MasonBrick *)brick;
- (void)setBrick:(MasonBrick *)brick;

- (MasonBrickView *)brickView;

- (IBAction)summonColorPanelForPalette:(id)sender;
- (IBAction)updatePaletteColorFromPanel:(id)sender;

- (IBAction)updateSliceAxis:(id)sender;
- (IBAction)moveSlice:(id)sender;

- (NSUInteger)currentPaletteColor;
- (void)updatePaletteIndex:(NSUInteger)index withColor:(NSColor *)color;

- (void)setBrickVoxel:(NSUInteger)index at:(struct point3)pt;
- (NSUInteger)brickVoxelAt:(struct point3)pt;

- (NSInteger)sliceAxis;
- (NSInteger)sliceNumber;

- (BOOL)canMoveSlice;
- (BOOL)canMovePreviousSlice;
- (BOOL)canMoveNextSlice;

- (BOOL)sliceAxisSurface;
- (BOOL)sliceAxisX;
- (BOOL)sliceAxisY;
- (BOOL)sliceAxisZ;

// private
- (MasonBrick *)_default_brick;
- (unsigned)_max_slice;
- (void)setSliceAxis:(NSInteger)sliceAxis;
- (void)setSliceNumber:(NSInteger)sliceNumber;

@end

#define SLICE_AXIS_SURFACE 0
#define SLICE_AXIS_XAXIS   1
#define SLICE_AXIS_YAXIS   2
#define SLICE_AXIS_ZAXIS   3

#define SLICE_MOVE_PREVIOUS 0
#define SLICE_MOVE_NEXT     1