#import <Cocoa/Cocoa.h>

@class MasonDocument;

@interface MasonResizeBrickController : NSObject
{
    MasonDocument * document;
    
    IBOutlet NSWindow * o_resizePanel;
    IBOutlet NSTextField * o_width, * o_height, * o_depth;
}

@property(readonly) NSUInteger width, height, depth;
@property MasonDocument * document;

- (MasonResizeBrickController *)initWithDocument:(MasonDocument *)document;

- (IBAction)doResize:(id)sender;
- (IBAction)cancelResize:(id)sender;

- (void)run;

@end
