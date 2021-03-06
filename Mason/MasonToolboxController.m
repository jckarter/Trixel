#import "MasonToolboxController.h"
#import "MasonRotateTool.h"
#import "MasonRotateLightTool.h"
#import "MasonDrawTool.h"
#import "MasonBuildTool.h"
#import "MasonEraseTool.h"
#import "MasonPushTool.h"
#import "MasonPullTool.h"
#import "MasonLowSelectionTool.h"
#import "MasonHighSelectionTool.h"

static NSArray * g_tools;

@interface MasonToolboxController ()
@property(readwrite) MasonTool * currentTool;
@property(readwrite) BOOL showBoundingBox, showAxes, showLighting, showSmoothShading, lockViewAngle;
@property(readwrite) BOOL lockSelectionX, lockSelectionY, lockSelectionZ;
@end

@implementation MasonToolboxController

@synthesize currentTool, showBoundingBox, showAxes, showLighting, showSmoothShading, lockViewAngle;
@synthesize lockSelectionX, lockSelectionY, lockSelectionZ;

- (MasonViewAngle *)lockedViewAngle
{
    return &m_lockedViewAngle;
}

+ (void)initialize
{
    g_tools = [[NSArray alloc] initWithObjects:
        [[MasonRotateTool alloc] init],
        [[MasonRotateLightTool alloc] init],
        [[MasonDrawTool   alloc] init],
        [[MasonEraseTool  alloc] init],
        [[MasonPushTool   alloc] init],
        [[MasonPullTool   alloc] init],
        [[MasonLowSelectionTool  alloc] init],
        [[MasonHighSelectionTool alloc] init],
        [[MasonBuildTool  alloc] init],
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

- (void)setShowSmoothShading:(BOOL)set
{
    showSmoothShading = set;
    [o_showSmoothShadingItem setState:(set ? NSOnState : NSOffState)];
}

- (void)setLockViewAngle:(BOOL)set
{
    lockViewAngle = set;
    [o_lockViewAngleItem setState:(set ? NSOnState : NSOffState)];
}

- (void)awakeFromNib
{
    MasonViewAngleInitialize(self.lockedViewAngle);
    
    self.currentTool = [g_tools objectAtIndex:0];
    self.showBoundingBox = self.showAxes = self.showLighting = self.showSmoothShading = YES;
}

- (IBAction)changeCurrentTool:(id)sender
{
    MasonTool * newTool = [g_tools objectAtIndex:[sender selectedTag]];
    if([newTool settingsDrawer] != [self.currentTool settingsDrawer])
    {
        [[self.currentTool settingsDrawer] close];
        [[newTool settingsDrawer] open];
    }
    self.currentTool = newTool;
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
- (IBAction)toggleShowSmoothShading:(id)sender
{
    self.showSmoothShading = !self.showSmoothShading;
}
- (IBAction)toggleLockViewAngle:(id)sender
{
    self.lockViewAngle = !self.lockViewAngle;
}

- (NSDrawer *)selectionDrawer
{
    return o_selectionDrawer;
}

@end
