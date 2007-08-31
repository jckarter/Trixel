#import <Cocoa/Cocoa.h>

#include "trixel.h"

@class MasonBrickView;

@interface MasonDocument : NSDocument
{
    IBOutlet NSSegmentedControl * o_sliceAxisSelector;
    IBOutlet MasonBrickView * o_brickView;
    
    trixel_brick * m_brick;
}

- (trixel_brick *)brick;
- (NSString *)brickSizeString;

- (MasonBrickView *)brickView;

// private
- (trixel_brick *)_read_default_brick;
- (void)_replace_brick:(trixel_brick *)new_brick;
@end

#define SLICE_AXIS_SURFACE 0
#define SLICE_AXIS_XAXIS   1
#define SLICE_AXIS_YAXIS   2
#define SLICE_AXIS_ZAXIS   3

