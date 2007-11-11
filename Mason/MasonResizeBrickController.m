#import "MasonDocument.h"
#import "MasonBrick.h"
#import "MasonResizeBrickController.h"

@implementation MasonResizeBrickController

@synthesize width, height, depth, document;

- (MasonResizeBrickController *)initWithDocument:(MasonDocument *)doc
{
    if(self = [super init]) {
        self.document = doc;
        self.width = doc.brick.width;
        self.height = doc.brick.height;
        self.depth = doc.brick.depth;
    }
    return self;
}

- (void)run
{
    if(!o_resizePanel)
        [NSBundle loadNibNamed:@"ResizeBrick" owner:self];
    
    [NSApp beginSheet:o_resizePanel
       modalForWindow:[self.document windowForSheet]
        modalDelegate:self
       didEndSelector:@selector(didEndSheet:returnCode:contextInfo:)
          contextInfo:NULL];
}

- (IBAction)doResize:(id)sender
{
    NSLog(@"resize to %u x %u x %u", self.width, self.height, self.depth);
    //[document resizeBrickToWidth:self.width height:self.height depth:self.depth];
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
