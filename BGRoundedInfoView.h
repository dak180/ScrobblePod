/* BGRoundedInfoView */

#import <Cocoa/Cocoa.h>
@class AppController;

@interface BGRoundedInfoView : NSView
{
	// CACHED IMAGES
	NSImage *statusImage;
	NSImage *backgroundImage;
	NSImage *stringImage;

	// INSTANCE VARIABLES
	int currentLoveHateIconOpacity;
	int currentBlueAction;
	float currentBlueOffset;
	BOOL isResizingBlue;
	BOOL blueIsClosed;
	BOOL active;
	NSRect drawingBounds;
	NSMutableArray *iconSet;
	NSDictionary *attributesDictionary;
	NSString *stringValue;
	//CTGradient *gradientFill;
	float currentScrollOffset;
	int hoveredIcon;
	int pressedIcon;
	
	BOOL scrobblingEnabled;
	BOOL scrobblingAuto;

	// TIMERS
	NSTimer *blueTimer;
	NSTimer *fadeIconTimer;
	NSTimer *statusChangeTimer;
	NSTimer *scrollTimer;
	
	NSString *properStringValue;
	
	IBOutlet AppController *appController;
}

@property (assign) BOOL scrobblingEnabled;
@property (assign) BOOL scrobblingAuto;
@property (assign) int hoveredIcon;
@property (assign) int pressedIcon;

@property (copy) NSString *properStringValue;

#pragma mark Initialisation
- (id)initWithFrame:(NSRect)frameRect;
-(void)createIconSet;

#pragma mark Last.fm Icons
-(void)addIconFromImage:(NSImage *)theImage withSelector:(NSString *)action andDescription:(NSString *)aDescription;
-(void)createTextAttributesDictionary;
-(NSString *)selectorNameForClickOffset:(NSPoint)clickPoint;
-(NSString *)descriptionForClickOffset:(NSPoint)clickPoint;
-(int)indexForClickOffset:(NSPoint)clickPoint;

#pragma mark Event Tracking
- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent;
-(void)mouseDown:(NSEvent *)theEvent;

#pragma mark Blue Timer
-(void)startBlueTimer;
-(void)stopBlueTimer;
-(void)incrementBlue:(NSTimer *)timer;
-(void)startBlueTimerWithDirection:(int)direction;
-(void)resetBlueToOffState;

#pragma mark Fade Timer
-(void)startFadeTimer;
-(void)stopFadeTimer;

#pragma mark Status Change Timer
-(void)startStatusChangeTimer;
-(void)stopStatusChangeTimer;

#pragma mark Convenience Blue Methods
-(float)currentBlueWidth;
-(void)openBlueMenu;
-(void)closeBlueMenu;

#pragma mark Drawing
-(void)drawRect:(NSRect)rect;
-(BOOL)isFlipped;

#pragma mark Calculating Regions
-(void)calculateDrawingBounds;

#pragma mark Generating Cached Images
-(NSImage *)backgroundImage;
-(void)generateBackgroundImage;
-(void)generateStringImage;
-(NSImage *)stringImageWithWidth:(float)theWidth andOffset:(float)theOffset;
-(void)generateStatusImage;

#pragma mark String Value
-(NSString *)stringValue;
-(void)setStringValue:(NSString *)aString;
-(void)setStringValue:(NSString *)aString isActive:(BOOL)aBool;
-(void)setTemporaryHoverStringValue:(NSString *)aString;
-(void)revertFromHoverToStringValue:(NSTimer*)theTimer;

#pragma mark Scrolling
-(void)startScrolling;
-(void)stopScrolling;
-(BOOL)shouldScroll;

#pragma mark Properties
@property (retain) NSImage *stringImage;
@property (retain) NSImage *statusImage;
@property (assign) BOOL active;
@property (assign) BOOL isResizingBlue;
@property (assign) int currentBlueAction;
@property (assign) int currentLoveHateIconOpacity;
@property (assign) BOOL blueIsClosed;

@end
