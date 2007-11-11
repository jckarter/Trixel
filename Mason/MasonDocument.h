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
    
    MasonBrick * brick;
    NSUInteger currentPaletteColor;
    NSInteger sliceAxis, sliceNumber;
}

@property MasonBrick * brick;
@property(readonly) NSUInteger currentPaletteColor;
@property(readonly) NSInteger sliceAxis, sliceNumber;

- (MasonBrickView *)brickView;

- (IBAction)summonColorPanelForPalette:(id)sender;
- (IBAction)updatePaletteColorFromPanel:(id)sender;

- (IBAction)updateSliceAxis:(id)sender;
- (IBAction)moveSlice:(id)sender;

- (IBAction)showResizePanel:(id)sender;

- (void)updatePaletteIndex:(NSUInteger)index withColor:(NSColor *)color;

- (void)setBrickVoxel:(NSUInteger)index at:(struct point3)pt;
- (NSUInteger)brickVoxelAt:(struct point3)pt;

- (BOOL)canMoveSlice;
- (BOOL)canMovePreviousSlice;
- (BOOL)canMoveNextSlice;

- (BOOL)sliceAxisSurface;
- (BOOL)sliceAxisX;
- (BOOL)sliceAxisY;
- (BOOL)sliceAxisZ;

@end

#define SLICE_AXIS_SURFACE 0
#define SLICE_AXIS_XAXIS   1
#define SLICE_AXIS_YAXIS   2
#define SLICE_AXIS_ZAXIS   3

#define SLICE_MOVE_PREVIOUS 0
#define SLICE_MOVE_NEXT     1