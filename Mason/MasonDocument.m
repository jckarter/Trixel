#import "MasonDocument.h"
#import "MasonColorCell.h"
#import "MasonBrick.h"
#import "MasonBrickView.h"
#include <stdlib.h>

@implementation MasonDocument

- (id)init
{
    self = [super init];
    if(self) {
        m_brick = [self _default_brick];
        [self setHasUndoManager:YES];
    }
    return self;
}

- (NSString *)windowNibName
{
    return @"MasonDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];
        
    [o_sliceAxisSelector selectSegmentWithTag:SLICE_AXIS_SURFACE];
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

- (unsigned int)currentPaletteColor
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

- (void)setBrickVoxel:(unsigned int)index at:(struct point3)pt;
{
    if(pt.x < 0.0)
        return;
        
    unsigned old = [m_brick voxelX:pt.x y:pt.y z:pt.z];
    if(index != old) {
        [[[self undoManager] prepareWithInvocationTarget:self] setBrickVoxel:old at:pt];
        [m_brick setVoxel:index x:pt.x y:pt.y z:pt.z];
    }
}

- (void)updatePaletteIndex:(unsigned)index withColor:(NSColor *)color
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

@end
