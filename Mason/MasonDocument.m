#import "MasonDocument.h"
#import "MasonColorCell.h"
#import "MasonCubeSelection.h"
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

@synthesize brick, currentPaletteColor, sliceAxis, sliceNumber, selection;

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
        selection = [MasonCubeSelection new];
        self.brick = [self _defaultBrick];
        [self selectAll:self];
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

- (IBAction)selectAll:(id)sender
{
    [self willChangeValueForKey:@"selection"];
    selection.minx = selection.miny = selection.minz = 0;
    selection.maxx = brick.width;
    selection.maxy = brick.height;
    selection.maxz = brick.depth;
    [self didChangeValueForKey:@"selection"];
}

- (IBAction)copy:(id)sender
{
    MasonBrick * pasteboardBrick = [self.brick selectedArea:self.selection];
    
    [[NSPasteboard generalPasteboard] declareTypes:[NSArray arrayWithObject:MasonBrickPboardType]
                                      owner:nil];
    [[NSPasteboard generalPasteboard] setData:[pasteboardBrick data] forType:MasonBrickPboardType];
}

- (IBAction)delete:(id)sender
{
    [self _replaceBrick:[self.brick clearingSelectedArea:self.selection]];
}

- (IBAction)cut:(id)sender
{
    [self copy:sender];
    [self delete:sender];
}

- (IBAction)paste:(id)sender
{
    if(![[[NSPasteboard generalPasteboard] types] containsObject:MasonBrickPboardType])
        return;

    NSData * pasteboardBrickData = [[NSPasteboard generalPasteboard] dataForType:MasonBrickPboardType];
    if(pasteboardBrickData) {
        NSError * error;
        MasonBrick * pasteboardBrick = [[MasonBrick alloc] initWithData:pasteboardBrickData withError:&error];
        if(pasteboardBrick)
            [self _replaceBrick:[self.brick replacingSelectedArea:self.selection withBrick:pasteboardBrick]];
    }
}

- (void)setLowSelectionPoint:(struct point3)pt
{
    [self willChangeValueForKey:@"selection"];
    selection.minx = pt.x;
    selection.miny = pt.y;
    selection.minz = pt.z;
    [self didChangeValueForKey:@"selection"];
}

- (void)setHighSelectionPoint:(struct point3)pt
{
    [self willChangeValueForKey:@"selection"];
    selection.maxx = pt.x+1;
    selection.maxy = pt.y+1;
    selection.maxz = pt.z+1;
    [self didChangeValueForKey:@"selection"];
}

- (NSSegmentedControl *)sliceAxisSelector
{
    return o_sliceAxisSelector;
}

- (NSString *)windowNibName
{
    return @"MasonDocument";
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    SEL action = [item action];
    
    if(action == @selector(moveSlice:)
        || action == @selector(copySlice:))
        return [self canMoveSlice] && ([item tag] == SLICE_MOVE_PREVIOUS
            ? [self canMovePreviousSlice]
            : [self canMoveNextSlice]
        );
    else if(action == @selector(projectSlice:))
        return [self canMoveSlice];
    else if(action == @selector(paste:))
        return [[[NSPasteboard generalPasteboard] types] containsObject:MasonBrickPboardType];
    return [super validateMenuItem:item];
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
    [self selectAll:self];
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

- (IBAction)copySlice:(id)sender
{
    if(![self canMoveSlice])
        return;

    NSInteger destSliceNumber = self.sliceNumber + ([sender tag] == SLICE_MOVE_PREVIOUS
        ? -1
        :  1);
    if(destSliceNumber >= 0 && destSliceNumber <= [self _maxSlice])
        [self _replaceBrick:[self.brick brickWithSliceAxis:self.sliceAxis
                                               sliceNumber:self.sliceNumber
                                       copiedToSliceNumber:destSliceNumber]];
    [self moveSlice:sender];
}

- (IBAction)projectSlice:(id)sender
{
    if(![self canMoveSlice])
        return;

    [self _replaceBrick:[self.brick brickWithSliceAxis:self.sliceAxis
                                  sliceNumberProjected:self.sliceNumber]];
}

- (BOOL)sliceAxisSurface    { return sliceAxis == SLICE_AXIS_SURFACE; }
- (BOOL)sliceAxisNotSurface { return sliceAxis != SLICE_AXIS_SURFACE; }
- (BOOL)sliceAxisX          { return sliceAxis == SLICE_AXIS_XAXIS;   }
- (BOOL)sliceAxisY          { return sliceAxis == SLICE_AXIS_YAXIS;   }
- (BOOL)sliceAxisZ          { return sliceAxis == SLICE_AXIS_ZAXIS;   }

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
    [self _replaceBrick:[self.brick shiftingSelectedArea:self.selection distance:POINT3(-1,  0,  0)]];
}
- (IBAction)shiftRight:(id)sender
{
    [self _replaceBrick:[self.brick shiftingSelectedArea:self.selection distance:POINT3( 1,  0,  0)]];
}
- (IBAction)shiftDown:(id)sender
{
    [self _replaceBrick:[self.brick shiftingSelectedArea:self.selection distance:POINT3( 0, -1,  0)]];
}
- (IBAction)shiftUp:(id)sender
{
    [self _replaceBrick:[self.brick shiftingSelectedArea:self.selection distance:POINT3( 0,  1,  0)]];
}
- (IBAction)shiftOut:(id)sender
{
    [self _replaceBrick:[self.brick shiftingSelectedArea:self.selection distance:POINT3( 0,  0, -1)]];
}
- (IBAction)shiftIn:(id)sender
{
    [self _replaceBrick:[self.brick shiftingSelectedArea:self.selection distance:POINT3( 0,  0,  1)]];
}

- (IBAction)mirrorLeft:(id)sender
{
    [self _replaceBrick:[self.brick mirroringSelectedArea:self.selection acrossAxis:POINT3(-1,  0,  0)]];
}
- (IBAction)mirrorRight:(id)sender
{
    [self _replaceBrick:[self.brick mirroringSelectedArea:self.selection acrossAxis:POINT3( 1,  0,  0)]];
}
- (IBAction)mirrorDown:(id)sender
{
    [self _replaceBrick:[self.brick mirroringSelectedArea:self.selection acrossAxis:POINT3( 0, -1,  0)]];
}
- (IBAction)mirrorUp:(id)sender
{
    [self _replaceBrick:[self.brick mirroringSelectedArea:self.selection acrossAxis:POINT3( 0,  1,  0)]];
}
- (IBAction)mirrorOut:(id)sender
{
    [self _replaceBrick:[self.brick mirroringSelectedArea:self.selection acrossAxis:POINT3( 0,  0, -1)]];
}
- (IBAction)mirrorIn:(id)sender
{
    [self _replaceBrick:[self.brick mirroringSelectedArea:self.selection acrossAxis:POINT3( 0,  0,  1)]];
}

- (IBAction)flipX:(id)sender
{
    [self _replaceBrick:[self.brick flippingSelectedArea:self.selection acrossAxis:POINT3(1, 0, 0)]];
}
- (IBAction)flipY:(id)sender
{
    [self _replaceBrick:[self.brick flippingSelectedArea:self.selection acrossAxis:POINT3(0, 1, 0)]];
}
- (IBAction)flipZ:(id)sender
{
    [self _replaceBrick:[self.brick flippingSelectedArea:self.selection acrossAxis:POINT3(0, 0, 1)]];
}

@end
