#import "MasonDocument.h"
#import "MasonColorCell.h"
#import "MasonBrick.h"
#import "MasonBrickView.h"
#import "MasonResizeBrickController.h"
#include <stdlib.h>

@interface MasonDocument ()

@property(readwrite) MasonBrick * brick;
@property(readwrite) NSUInteger currentPaletteColor;
@property(readwrite) NSInteger sliceAxis, sliceNumber;

- (MasonBrick *)_defaultBrick;
- (unsigned)_maxSlice;
- (void)_replaceBrick:(MasonBrick *)newBrick;

@end

@implementation MasonDocument

@synthesize brick, currentPaletteColor, sliceAxis, sliceNumber;

+ (void)initialize
{
    [self setKeys:[NSArray arrayWithObject:@"sliceAxis"]
          triggerChangeNotificationsForDependentKey:@"canMoveSlice"];
    [self setKeys:[NSArray arrayWithObject:@"sliceAxis"]
          triggerChangeNotificationsForDependentKey:@"sliceAxisSurface"];
    [self setKeys:[NSArray arrayWithObject:@"sliceAxis"]
          triggerChangeNotificationsForDependentKey:@"sliceAxisX"];
    [self setKeys:[NSArray arrayWithObject:@"sliceAxis"]
          triggerChangeNotificationsForDependentKey:@"sliceAxisY"];
    [self setKeys:[NSArray arrayWithObject:@"sliceAxis"]
          triggerChangeNotificationsForDependentKey:@"sliceAxisZ"];

    [self setKeys:[NSArray arrayWithObject:@"sliceNumber"]
          triggerChangeNotificationsForDependentKey:@"canMovePreviousSlice"];
    [self setKeys:[NSArray arrayWithObject:@"sliceNumber"]
          triggerChangeNotificationsForDependentKey:@"canMoveNextSlice"];
}

- (id)init
{
    self = [super init];
    if(self) {
        self.brick = [self _defaultBrick];
        [self setHasUndoManager:YES];
    }
    return self;
}

- (void)setBrick:(MasonBrick *)newBrick
{
    brick.scriptingContainer = nil;
    newBrick.scriptingContainer = self;
    brick = newBrick;
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
    self.sliceAxis = SLICE_AXIS_SURFACE;
    self.sliceNumber = 0;
    self.currentPaletteColor = 1;
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
    self.currentPaletteColor = [sender clickedRow];
    [colorPanel setTarget:self];
    [colorPanel setAction:@selector(updatePaletteColorFromPanel:)];
    [colorPanel setShowsAlpha:NO]; //YES];
	[colorPanel setColor:[brick objectInPaletteColorsAtIndex:self.currentPaletteColor]];
	[colorPanel makeKeyAndOrderFront:self];
    [o_paletteController setSelectionIndex:self.currentPaletteColor];
}

- (IBAction)updatePaletteColorFromPanel:(id)sender
{
    [self updatePaletteIndex:self.currentPaletteColor withColor:[sender color]];
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)out_error
{
    return [self.brick data];
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)out_error
{
    self.brick = [[MasonBrick alloc] initWithData:data withError:out_error];
    return !!brick;
}

- (MasonBrickView *)brickView
{
    return o_brickView;
}

- (void)setBrickVoxel:(NSUInteger)index at:(struct point3)pt;
{
    if(pt.x < 0.0)
        return;
        
    unsigned old = [brick voxelX:pt.x y:pt.y z:pt.z];
    if(index != old) {
        [[[self undoManager] prepareWithInvocationTarget:self] setBrickVoxel:old at:pt];
        [brick setVoxel:index x:pt.x y:pt.y z:pt.z];
    }
}

- (NSUInteger)brickVoxelAt:(struct point3)pt
{
    if(pt.x < 0.0)
        return (NSUInteger)-1;

    return [brick voxelX:pt.x y:pt.y z:pt.z];    
}

- (void)updatePaletteIndex:(NSUInteger)index withColor:(NSColor *)color
{
    NSColor * oldColor = [brick objectInPaletteColorsAtIndex:index];
    if([color isEqualTo:oldColor])
        return;
    
    [[[self undoManager] prepareWithInvocationTarget:self]
        updatePaletteIndex:index
        withColor:oldColor];
    [brick replaceObjectInPaletteColorsAtIndex:index withObject:color];
}

- (MasonBrick *)_defaultBrick
{
    NSError *error;
    return [[MasonBrick alloc] initSolidWithWidth:16 height:16 depth:16
                               withError:&error];
}

- (IBAction)updateSliceAxis:(id)sender
{
    NSInteger tag = [sender respondsToSelector:@selector(selectedSegment)]
        ? [sender selectedSegment]
        : [sender tag];
        
    self.sliceAxis = tag;
    self.sliceNumber = 0;
    [o_sliceAxisSelector setSelectedSegment:tag];
}

- (unsigned)_maxSlice
{
    switch(sliceAxis) {
        case SLICE_AXIS_SURFACE:
            return 0;
        case SLICE_AXIS_XAXIS:
            return [brick width] - 1;
        case SLICE_AXIS_YAXIS:
            return [brick height] - 1;
        case SLICE_AXIS_ZAXIS:
            return [brick depth] - 1;
    }
    NSLog(@"fell out of _max_slice ?!?!?");
    return 0;
}

- (IBAction)moveSlice:(id)sender
{
    NSInteger tag = [sender respondsToSelector:@selector(selectedSegment)]
        ? [sender selectedSegment]
        : [sender tag];
        
    if(tag == SLICE_MOVE_PREVIOUS
        && [self canMovePreviousSlice])
        --self.sliceNumber;
    else if(tag == SLICE_MOVE_NEXT
            && [self canMoveNextSlice])
        ++self.sliceNumber;
}

- (BOOL)canMoveSlice
{
    return self.sliceAxis != SLICE_AXIS_SURFACE;
}

- (BOOL)canMovePreviousSlice
{
    return self.sliceNumber > 0;
}

- (BOOL)canMoveNextSlice
{
    return self.sliceNumber < [self _maxSlice];
}

- (BOOL)sliceAxisSurface { return sliceAxis == SLICE_AXIS_SURFACE; }
- (BOOL)sliceAxisX       { return sliceAxis == SLICE_AXIS_XAXIS;   }
- (BOOL)sliceAxisY       { return sliceAxis == SLICE_AXIS_YAXIS;   }
- (BOOL)sliceAxisZ       { return sliceAxis == SLICE_AXIS_ZAXIS;   }

- (IBAction)showResizePanel:(id)sender
{
    MasonResizeBrickController * controller = [[MasonResizeBrickController alloc] initWithDocument:self];
    [controller run];
}

- (void)_replaceBrick:(MasonBrick *)newBrick
{
    [[[self undoManager] prepareWithInvocationTarget:self] _replaceBrick:self.brick];
    self.brick = newBrick;
}

- (void)resizeBrickToWidth:(NSUInteger)width height:(NSUInteger)height depth:(NSUInteger)depth
{
    [self _replaceBrick:[self.brick resizedToWidth:width height:height depth:depth]];
    self.sliceAxis = SLICE_AXIS_SURFACE;
    self.sliceNumber = 0;
    [o_sliceAxisSelector setSelectedSegment:SLICE_AXIS_SURFACE];
}

- (IBAction)shiftLeft:(id)sender
{
    [self _replaceBrick:[self.brick shifted:POINT3(-1,  0,  0)]];
}
- (IBAction)shiftRight:(id)sender
{
    [self _replaceBrick:[self.brick shifted:POINT3( 1,  0,  0)]];
}
- (IBAction)shiftDown:(id)sender
{
    [self _replaceBrick:[self.brick shifted:POINT3( 0, -1,  0)]];
}
- (IBAction)shiftUp:(id)sender
{
    [self _replaceBrick:[self.brick shifted:POINT3( 0,  1,  0)]];
}
- (IBAction)shiftOut:(id)sender
{
    [self _replaceBrick:[self.brick shifted:POINT3( 0,  0, -1)]];
}
- (IBAction)shiftIn:(id)sender
{
    [self _replaceBrick:[self.brick shifted:POINT3( 0,  0,  1)]];
}

- (IBAction)mirrorLeft:(id)sender
{
    [self _replaceBrick:[self.brick mirrored:POINT3(-1,  0,  0)]];
}
- (IBAction)mirrorRight:(id)sender
{
    [self _replaceBrick:[self.brick mirrored:POINT3( 1,  0,  0)]];
}
- (IBAction)mirrorDown:(id)sender
{
    [self _replaceBrick:[self.brick mirrored:POINT3( 0, -1,  0)]];
}
- (IBAction)mirrorUp:(id)sender
{
    [self _replaceBrick:[self.brick mirrored:POINT3( 0,  1,  0)]];
}
- (IBAction)mirrorOut:(id)sender
{
    [self _replaceBrick:[self.brick mirrored:POINT3( 0,  0, -1)]];
}
- (IBAction)mirrorIn:(id)sender
{
    [self _replaceBrick:[self.brick mirrored:POINT3( 0,  0,  1)]];
}

- (IBAction)flipX:(id)sender
{
    [self _replaceBrick:[self.brick flipped:POINT3(1, 0, 0)]];
}
- (IBAction)flipY:(id)sender
{
    [self _replaceBrick:[self.brick flipped:POINT3(0, 1, 0)]];
}
- (IBAction)flipZ:(id)sender
{
    [self _replaceBrick:[self.brick flipped:POINT3(0, 0, 1)]];
}

@end
