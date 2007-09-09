// Courtesy of John Harte

#import "MasonColorCell.h"

@implementation MasonColorCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView*)controlView
{
	NSRect square = NSInsetRect(cellFrame, 0.5, 0.5);
	
	if (square.size.height < square.size.width) {
		square.size.width = square.size.height;
		square.origin.x = square.origin.x + (cellFrame.size.width - square.size.width) / 2.0;
	} else {
		square.size.height = square.size.width;
		square.origin.y = square.origin.y + (cellFrame.size.height - square.size.height) / 2.0;
	}

	[[NSColor blackColor] set];
	[NSBezierPath strokeRect: square];

	[[self objectValue] drawSwatchInRect: NSInsetRect (square, 2.0, 2.0)];
}


@end
