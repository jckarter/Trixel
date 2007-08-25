#import <Cocoa/Cocoa.h>

@class MasonBrickView;

@interface MasonDocument : NSDocument
{
    IBOutlet NSSegmentedControl *o_sliceAxisSelector;
}
@end

#define SLICE_AXIS_SURFACE 0
#define SLICE_AXIS_XAXIS   1
#define SLICE_AXIS_YAXIS   2
#define SLICE_AXIS_ZAXIS   3

