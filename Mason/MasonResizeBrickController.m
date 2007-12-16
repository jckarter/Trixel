#import "MasonDocument.h"
#import "MasonBrick.h"
#import "MasonResizeBrickController.h"

@implementation MasonResizeBrickController

@synthesize document;

- (NSUInteger)width
{
    return [o_width intValue];
}

- (NSUInteger)height
{
    return [o_height intValue];
}

- (NSUInteger)depth
{
    return [o_depth intValue];
}

- (MasonResizeBrickController *)initWithDocument:(MasonDocument *)doc
{
    if(self = [super init]) {
        self.document = doc;
    }
    return self;
}

- (void)run
{
    if(!o_resizePanel)
        [NSBundle loadNibNamed:@"ResizeBrick" owner:self];

    [o_width setIntValue:self.document.brick.width];
    [o_height setIntValue:self.document.brick.height];
    [o_depth setIntValue:self.document.brick.depth];
    
    [NSApp beginSheet:o_resizePanel
       modalForWindow:[self.document windowForSheet]
        modalDelegate:self
       didEndSelector:@selector(didEndSheet:returnCode:contextInfo:)
          contextInfo:NULL];
}

- (IBAction)doResize:(id)sender
{
    [document resizeBrickToWidth:self.width height:self.height depth:self.depth];
    [NSApp endSheet:o_resizePanel];
}

- (IBAction)cancelResize:(id)sender
{
    [NSApp endSheet:o_resizePanel];
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)info
{
    [sheet orderOut:self];
}

@end
