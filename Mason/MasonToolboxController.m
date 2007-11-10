#import "MasonToolboxController.h"
#import "MasonRotateTool.h"
#import "MasonDrawTool.h"
#import "MasonBuildTool.h"
#import "MasonEraseTool.h"
#import "MasonPushTool.h"
#import "MasonPullTool.h"

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
    g_tools = [[NSArray alloc] initWithObjects:
        [[MasonRotateTool alloc] init],
        [[MasonDrawTool   alloc] init],
        [[MasonBuildTool  alloc] init],
        [[MasonEraseTool  alloc] init],
        [[MasonPushTool   alloc] init],
        [[MasonPullTool   alloc] init],
        NULL
    ];
}

- (void)awakeFromNib
{
    m_currentTool = [g_tools objectAtIndex:0];
}

- (IBAction)changeCurrentTool:(id)sender
{
    [self willChangeValueForKey:@"currentTool"];
    m_currentTool = [g_tools objectAtIndex:[sender selectedTag]];
    [self didChangeValueForKey:@"currentTool"];
}

- (MasonTool *)currentTool
{
    return m_currentTool;
}

@end
