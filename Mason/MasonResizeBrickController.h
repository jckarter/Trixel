#import <Cocoa/Cocoa.h>

@class MasonDocument;

@interface MasonResizeBrickController : NSObject
{
    MasonDocument * document;
    NSUInteger width, height, depth;
    
    IBOutlet NSWindow * o_resizePanel;
}

@property NSUInteger width, height, depth;
@property MasonDocument * document;

- (MasonResizeBrickController *)initWithDocument:(MasonDocument *)document;

- (IBAction)doResize:(id)sender;
- (IBAction)cancelResize:(id)sender;

- (void)run;

@end
