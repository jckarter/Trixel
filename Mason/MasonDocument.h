#include <GL/glew.h>
#import <Cocoa/Cocoa.h>
#include "trixel.h"

@class MasonBrickView;
@class MasonBrick;
@class MasonCubeSelection;

@interface MasonDocument : NSDocument
{
    IBOutlet NSSegmentedControl * o_sliceAxisSelector, *o_sliceMover;
    IBOutlet MasonBrickView * o_brickView;
    IBOutlet NSTableView *o_paletteTableView;
    IBOutlet NSArrayController *o_paletteController;
    
    MasonBrick * brick;
    NSUInteger currentPaletteColor;
    NSInteger sliceAxis, sliceNumber;

    MasonCubeSelection * selection;
}

@property(readonly) MasonBrick * brick;
@property(readonly) NSUInteger currentPaletteColor;
@property(readonly) NSInteger sliceAxis, sliceNumber;
@property(readonly) MasonCubeSelection * selection;

- (MasonBrickView *)brickView;

- (IBAction)summonColorPanelForPalette:(id)sender;
- (IBAction)updatePaletteColorFromPanel:(id)sender;

- (IBAction)updateSliceAxis:(id)sender;
- (IBAction)moveSlice:(id)sender;

- (IBAction)copySlice:(id)sender;
- (IBAction)projectSlice:(id)sender;

- (IBAction)showResizePanel:(id)sender;

- (IBAction)shiftLeft:(id)sender;
- (IBAction)shiftRight:(id)sender;
- (IBAction)shiftDown:(id)sender;
- (IBAction)shiftUp:(id)sender;
- (IBAction)shiftOut:(id)sender;
- (IBAction)shiftIn:(id)sender;

- (IBAction)mirrorLeft:(id)sender;
- (IBAction)mirrorRight:(id)sender;
- (IBAction)mirrorDown:(id)sender;
- (IBAction)mirrorUp:(id)sender;
- (IBAction)mirrorOut:(id)sender;
- (IBAction)mirrorIn:(id)sender;

- (IBAction)selectAll:(id)sender;

- (IBAction)flipX:(id)sender;
- (IBAction)flipY:(id)sender;
- (IBAction)flipZ:(id)sender;

- (void)setLowSelectionPoint:(struct point3)pt;
- (void)setHighSelectionPoint:(struct point3)pt;

- (void)updatePaletteIndex:(NSUInteger)index withColor:(NSColor *)color;

- (void)setBrickVoxel:(NSUInteger)index at:(struct point3)pt;
- (NSUInteger)brickVoxelAt:(struct point3)pt;
- (void)resizeBrickToWidth:(NSUInteger)width height:(NSUInteger)height depth:(NSUInteger)depth;

- (BOOL)canMoveSlice;
- (BOOL)canMovePreviousSlice;
- (BOOL)canMoveNextSlice;

- (BOOL)sliceAxisSurface;
- (BOOL)sliceAxisNotSurface;
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