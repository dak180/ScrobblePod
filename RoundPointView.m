//
//  RoundPointView.m
//  PointWindow
//
//  Created by Ben Gummer on 22/04/08.
//  Copyright 2008 Ben Gummer. All rights reserved.
//

#import "RoundPointView.h"

@implementation RoundPointView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.triangleCenter = frame.size.width/2;
		self.triangleHeight = 15.0;
		self.cornerRadius = 8.0;
		self.triangleWidth = 30.0;
    }
    return self;
}

- (void)drawRect:(NSRect)rect {
	NSRect realSize = [self bounds];
	float entireWidth = realSize.size.width;
	float entireHeight = realSize.size.height;

	NSBezierPath *bezierPath = [NSBezierPath bezierPath];
	[bezierPath setLineWidth:0.5];

	//bottom left
	[bezierPath appendBezierPathWithArcWithCenter:NSMakePoint(cornerRadius, cornerRadius) radius:cornerRadius startAngle:180.0 endAngle:270.0];
	//bottom right
	[bezierPath appendBezierPathWithArcWithCenter:NSMakePoint(entireWidth-cornerRadius, cornerRadius) radius:cornerRadius startAngle:270.0 endAngle:360.0];
	//top right
	[bezierPath appendBezierPathWithArcWithCenter:NSMakePoint(entireWidth-cornerRadius, entireHeight-cornerRadius-triangleHeight) radius:cornerRadius startAngle:  0.0 endAngle: 90.0];
	//triangle
	[bezierPath lineToPoint:NSMakePoint(triangleCenter+(triangleWidth/2),entireHeight-triangleHeight)];
	[bezierPath lineToPoint:NSMakePoint(triangleCenter,entireHeight)];
	[bezierPath lineToPoint:NSMakePoint(triangleCenter-(triangleWidth/2),entireHeight-triangleHeight)];
	//top left
	[bezierPath appendBezierPathWithArcWithCenter:NSMakePoint(cornerRadius, entireHeight-cornerRadius-triangleHeight) radius:cornerRadius startAngle: 90.0 endAngle:180.0];

	[bezierPath closePath];
	
    NSGradient *backgroundGradient = [[[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedRed:0.75 green:0.75 blue:0.75 alpha:1.00] endingColor:[NSColor colorWithCalibratedRed:0.90 green:0.90 blue:0.90 alpha:1.00]] autorelease];
    [backgroundGradient drawInBezierPath:bezierPath angle:90];
    
//	[[CTGradient unifiedNormalGradient] fillBezierPath:bezierPath angle:90.0];
	[[NSColor darkGrayColor] set];
	[bezierPath setFlatness:0.1];
	[bezierPath stroke];
	
/*	NSBezierPath *highlightLine = [NSBezierPath bezierPath];
	[highlightLine moveToPoint:NSMakePoint(cornerRadius, entireHeight-triangleHeight-2)];
	[highlightLine lineToPoint:NSMakePoint(triangleCenter-(triangleWidth/2), entireHeight-triangleHeight-2)];
	
	[highlightLine moveToPoint:NSMakePoint(triangleCenter+(triangleWidth/2), entireHeight-triangleHeight-2)];
	[highlightLine lineToPoint:NSMakePoint(entireWidth-cornerRadius, entireHeight-triangleHeight-2)];
	[highlightLine closePath];
	
	[[NSColor colorWithCalibratedWhite:1.0 alpha:1.0] set];
	[highlightLine setLineWidth:0.5];
	[highlightLine stroke];*/
}

-(BOOL)acceptsFirstResponder {
	return YES;
}

-(BOOL)canBecomeKeyView {
	return YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent {
	return YES;
}

@synthesize triangleCenter;
@synthesize triangleHeight;
@synthesize triangleWidth;
@synthesize cornerRadius;

@end
