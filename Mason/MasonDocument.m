#import "MasonDocument.h"

@implementation MasonDocument

- (id)init
{
    self = [super init];
    if(self) {
    
        // Add your subclass-specific initialization here.
        // If an error occurs here, send a [self release] message and return nil.
    
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
    
    for(int i = 0; i < [o_sliceAxisSelector segmentCount]; ++i)
        [o_sliceAxisSelector setLabel:nil forSegment:i];
    [o_sliceAxisSelector selectSegmentWithTag:SLICE_AXIS_SURFACE];
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)out_error
{
    return nil;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)out_error
{
    return YES;
}

@end
