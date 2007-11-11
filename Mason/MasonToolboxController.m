#import "MasonToolboxController.h"
#import "MasonRotateTool.h"
#import "MasonDrawTool.h"
#import "MasonBuildTool.h"
#import "MasonEraseTool.h"
#import "MasonPushTool.h"
#import "MasonPullTool.h"

static NSArray * g_tools;

@interface MasonToolboxController ()
@property(readwrite) MasonTool * currentTool;
@end

@implementation MasonToolboxController

@synthesize currentTool;

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
    self.currentTool = [g_tools objectAtIndex:0];
}

- (IBAction)changeCurrentTool:(id)sender
{
    self.currentTool = [g_tools objectAtIndex:[sender selectedTag]];
}

@end
