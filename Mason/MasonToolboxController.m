#import <Cocoa/Cocoa.h>
#import "MasonToolboxController.h"
#import "MasonRotateTool.h"
#import "MasonDrawTool.h"
#import "MasonEraseTool.h"

static NSArray * g_tools;

@implementation MasonToolboxController

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
    if([key isEqualToString:@"currentTool"])
        return NO;
    else
        return [super automaticallyNotifiesObserversForKey:key];
}

+ (void)initialize
{
    NSLog(@"initialize MasonToolboxController");
    g_tools = [[NSArray alloc] initWithObjects:
        [[MasonRotateTool alloc] init],
        [[MasonDrawTool alloc] init],
        [[MasonEraseTool alloc] init],
        NULL
    ];
}

- (void)awakeFromNib
{
    NSLog(@"awakeFromNib MasonToolboxController %@", self);
    m_currentTool = [g_tools objectAtIndex:0];
    
    NSLog(@"%@ == %@", m_currentTool, [self currentTool]);
}

- (IBAction)changeCurrentTool:(id)sender
{
    NSLog(@"changeCurrentTool from %@ tag %d", sender, [sender selectedTag]);
    [self willChangeValueForKey:@"hoverPoint"];
    m_currentTool = [g_tools objectAtIndex:[sender selectedTag]];
    [self didChangeValueForKey:@"hoverPoint"];
}

- (MasonTool *)currentTool
{
    return m_currentTool;
}

@end
