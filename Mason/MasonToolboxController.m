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
@property(readwrite) BOOL showBoundingBox, showAxes, showLighting;
@end

@implementation MasonToolboxController

@synthesize currentTool, showBoundingBox, showAxes, showLighting;

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

- (void)setShowBoundingBox:(BOOL)set
{
    showBoundingBox = set;
    [o_showBoundingBoxItem setState:(set ? NSOnState : NSOffState)];
}

- (void)setShowAxes:(BOOL)set
{
    showAxes = set;
    [o_showAxesItem setState:(set ? NSOnState : NSOffState)];
}

- (void)setShowLighting:(BOOL)set
{
    showLighting = set;
    [o_showLightingItem setState:(set ? NSOnState : NSOffState)];
}

- (void)awakeFromNib
{
    self.currentTool = [g_tools objectAtIndex:0];
    self.showBoundingBox = self.showAxes = self.showLighting = YES;
}

- (IBAction)changeCurrentTool:(id)sender
{
    self.currentTool = [g_tools objectAtIndex:[sender selectedTag]];
}

- (IBAction)toggleShowBoundingBox:(id)sender
{
    self.showBoundingBox = !self.showBoundingBox;
}
- (IBAction)toggleShowAxes:(id)sender
{
    self.showAxes = !self.showAxes;
}
- (IBAction)toggleShowLighting:(id)sender
{
    self.showLighting = !self.showLighting;
}

@end
