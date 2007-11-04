#import "MasonDocument.h"
#import "MasonColorCell.h"
#import "MasonBrick.h"
#import "MasonBrickView.h"
#include <stdlib.h>

@implementation MasonDocument

+ (void)initialize
{
    [self setKeys:[NSArray arrayWithObject:@"sliceAxis"]
          triggerChangeNotificationsForDependentKey:@"canMoveSlice"];
}

- (id)init
{
    self = [super init];
    if(self) {
        m_brick = [self _default_brick];
        [self setHasUndoManager:YES];
    }
    return self;
}

- (NSSegmentedControl *)sliceAxisSelector
{
    return o_sliceAxisSelector;
}

- (NSString *)windowNibName
{
    return @"MasonDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];
        
    [o_sliceAxisSelector selectSegmentWithTag:SLICE_AXIS_SURFACE];
    [self setSliceAxis:SLICE_AXIS_SURFACE];
    [self setSliceNumber:0];
    m_currentPaletteColor = 1;
    [o_paletteController setSelectionIndex:1];
    
    NSTableColumn * paletteColumn = [[o_paletteTableView tableColumns] objectAtIndex:0];
    MasonColorCell * colorCell = [[MasonColorCell alloc] init];
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
	[colorPanel setColor:[m_brick objectInPaletteColorsAtIndex:m_currentPaletteColor]];
	[colorPanel makeKeyAndOrderFront:self];
    [o_paletteController setSelectionIndex:m_currentPaletteColor];
}

- (IBAction)updatePaletteColorFromPanel:(id)sender
{
    [self updatePaletteIndex:m_currentPaletteColor withColor:[sender color]];
}

- (NSUInteger)currentPaletteColor
{
    return m_currentPaletteColor;
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)out_error
{
    return [m_brick data];
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)out_error
{
    [self setBrick:[[MasonBrick alloc] initWithData:data withError:out_error]];
    return !!m_brick;
}

- (void)setBrick:(MasonBrick *)brick
{
    m_brick = brick;
}

- (MasonBrick *)brick
{
    return m_brick;
}

- (MasonBrickView *)brickView
{
    return o_brickView;
}

- (void)setBrickVoxel:(NSUInteger)index at:(struct point3)pt;
{
    if(pt.x < 0.0)
        return;
        
    unsigned old = [m_brick voxelX:pt.x y:pt.y z:pt.z];
    if(index != old) {
        [[[self undoManager] prepareWithInvocationTarget:self] setBrickVoxel:old at:pt];
        [m_brick setVoxel:index x:pt.x y:pt.y z:pt.z];
    }
}

- (void)updatePaletteIndex:(NSUInteger)index withColor:(NSColor *)color
{
    NSColor * oldColor = [m_brick objectInPaletteColorsAtIndex:index];
    if([color isEqualTo:oldColor])
        return;
    
    [[[self undoManager] prepareWithInvocationTarget:self]
        updatePaletteIndex:index
        withColor:oldColor];
    [m_brick replaceObjectInPaletteColorsAtIndex:index withObject:color];
}

- (MasonBrick *)_default_brick
{
    NSError *error;
    return [[MasonBrick alloc] initWithContentsOfFile:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"default.brick"]
                                withError:&error];
}

- (IBAction)updateSliceAxis:(id)sender
{
    [self setSliceAxis:[o_sliceAxisSelector selectedSegment]];
    [self setSliceNumber:0];
}

- (unsigned)_max_slice
{
    switch(m_sliceAxis) {
        case SLICE_AXIS_SURFACE:
            return 0;
        case SLICE_AXIS_XAXIS:
            return [m_brick width] - 1;
        case SLICE_AXIS_YAXIS:
            return [m_brick height] - 1;
        case SLICE_AXIS_ZAXIS:
            return [m_brick depth] - 1;
    }
    NSLog(@"fell out of _max_slice ?!?!?");
    return 0;
}

- (IBAction)moveSlice:(id)sender
{
    if([sender selectedSegment] == SLICE_MOVE_PREVIOUS
        && [self canMovePreviousSlice])
        [self setSliceNumber:[self sliceNumber] - 1];
    else if([sender selectedSegment] == SLICE_MOVE_NEXT
            && [self canMoveNextSlice])
        [self setSliceNumber:[self sliceNumber] + 1];
}

- (BOOL)canMoveSlice
{
    NSLog(@"canMoveSlice axis %d", m_sliceAxis);
    return m_sliceAxis != SLICE_AXIS_SURFACE;
}

- (BOOL)canMovePreviousSlice
{
    NSLog(@"canMovePreviousSlice axis %d number %d", m_sliceAxis, m_sliceNumber);
    return m_sliceNumber > 0;
}

- (BOOL)canMoveNextSlice
{
    NSLog(@"canMoveNextSlice axis %d number %d max slice %d", m_sliceAxis, m_sliceNumber, [self _max_slice]);
    return m_sliceNumber < [self _max_slice];
}

- (NSInteger)sliceAxis
{
    return m_sliceAxis;
}
- (NSInteger)sliceNumber
{
    return m_sliceNumber;
}
- (void)setSliceAxis:(NSInteger)sliceAxis
{
    m_sliceAxis = sliceAxis;
}
- (void)setSliceNumber:(NSInteger)sliceNumber
{
    m_sliceNumber = sliceNumber;
    [o_sliceMover setEnabled:[self canMovePreviousSlice] forSegment:SLICE_MOVE_PREVIOUS];
    [o_sliceMover setEnabled:[self canMoveNextSlice] forSegment:SLICE_MOVE_NEXT];
}

@end
