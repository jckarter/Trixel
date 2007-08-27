#import "MasonDocument.h"
#include <stdlib.h>

NSString *TrixelErrorDomain = @"TrixelErrorDomain";

static NSError *
nserror_from_trixel_error(char *cstring)
{
    NSString *string = [NSString stringWithUTF8String:cstring],
             *first_line, *rest;
    free(cstring); //// frees trixel error string!
    NSRange first_newline = [string rangeOfString:@"\n"];
    if(first_newline.location == NSNotFound) {
        first_line = string;
        rest = nil;
    }
    else {
        first_line = [string substringToIndex:first_newline.location];
        rest = [string substringFromIndex:first_newline.location + first_newline.length];
    }
    
    NSDictionary *errorDict = [NSDictionary dictionaryWithObjectsAndKeys:
        first_line, NSLocalizedDescriptionKey,
        rest, NSLocalizedRecoverySuggestionErrorKey,
        nil
    ];
    
    return [NSError errorWithDomain:TrixelErrorDomain code:0 userInfo:errorDict];
}

@implementation MasonDocument

- (id)init
{
    self = [super init];
    if(self) {
        [self _read_default_brick];
    }
    return self;
}

- (void)dealloc
{
    if(m_brick)
        trixel_free_brick(m_brick);
    [super dealloc];
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
    char * error_message;

    trixel_brick * new_brick = trixel_read_brick((void *)[data bytes], [data length], false, &error_message);
    
    if(!new_brick) {
        *out_error = nserror_from_trixel_error(error_message);
        return NO;
    }
    
    if(m_brick)
        trixel_free_brick(m_brick);
    m_brick = new_brick;
    
    return YES;
}

- (trixel_brick *)brick
{
    return m_brick;
}

- (trixel_brick *)_read_default_brick
{
    char * error_message;
    m_brick = trixel_read_brick_from_filename(
        [[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"default.brick"] UTF8String],
        false, &error_message
    );
    
    return m_brick;
}

@end
