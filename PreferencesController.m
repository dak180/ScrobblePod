#import "PreferencesController.h"
#import "SFHFKeychainUtils.h"
#import "Defines.h"
#import "iPodWatcher.h"
#import <Security/Security.h>
#import <QuartzCore/CoreAnimation.h>
#import "HubStrings.h"
#import "HubNotifications.h"

#define maxItems 10 // Cutoff for history items

@implementation PreferencesController

#pragma mark WindowController Methods

- (id) init {
	self = [super initWithWindowNibName:@"Preferences"];
	if (self != nil) {
	}
	return self;
}

- (void)windowDidLoad {
//	[self.window setLevel:NSModalPanelWindowLevel]; // Disabled since 0.51 preview 3
	[self.window center];
	[self.window setShowsToolbarButton:NO];
	
	NSImageCell *theCell = [[NSImageCell alloc] init];
	[historyIconTableColumn setDataCell:theCell];
	[theCell release];
	
	// set the button state for whether we open at login:
	NSString * appPath = [[NSBundle mainBundle] bundlePath];

	LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
	if ([self loginItemExistsWithLoginItemReference:loginItems ForPath:appPath]) {
		[startAtLogin setState:NSOnState];
	} else {
		[startAtLogin setState:NSOffState];
	}

	CFRelease(loginItems);
	
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	[notificationCenter addObserver:self selector:@selector(loginProcessing) name:APIHUB_WebServiceAuthorizationProcessing object:nil];
	[notificationCenter addObserver:self selector:@selector(loginComplete) name:APIHUB_WebServiceAuthorizationCompleted  object:nil];
	
	NSString *username = [[NSUserDefaults standardUserDefaults] stringForKey:@"Username"];
	if (!username || username.length==0) [currentLoginContainer setHidden:YES];
	self.window.contentView = generalPrefsView;
//	[self setPreferencesView:generalPrefsView];	
}

- (NSString *)windowNibName {
	return @"Preferences";
}

- (IBAction)showWindow:(id)sender {
	[self.window setCollectionBehavior: NSWindowCollectionBehaviorCanJoinAllSpaces];
	if (![self.window isVisible]) {
		[prefToolbar setVisible:NO];
		[self changeView:generalPrefsToolbarItem];
	}
	[super showWindow:self];
	[NSApp activateIgnoringOtherApps:YES];
	[prefToolbar setVisible:YES];
}

#pragma mark Toolbar

-(BOOL)validateToolbarItem:(NSToolbarItem *)theItem {
    return YES;
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar {
	
	NSMutableArray *theArray = [NSMutableArray new];
	NSToolbarItem *currentItem;
	for (currentItem in [toolbar items]) {
		[theArray addObject:currentItem.itemIdentifier];
	}
	[theArray autorelease];
	return theArray;
}

#pragma mark Changing Views

-(IBAction)changeView:(NSToolbarItem *)sender {
	[prefToolbar setSelectedItemIdentifier:sender.itemIdentifier];
	if ([sender tag]==1) {
		[self setPreferencesView:generalPrefsView];
	} else if ([sender tag]==3) {
		[self setPreferencesView:lastfmPrefsView];
	} else if ([sender tag]==4) {
		[self setPreferencesView:exclusionsView];
	} else if ([sender tag]==6) {
		[self setPreferencesView:historyView];
	}
}

-(void)setPreferencesView:(NSView *)inputView {
	if (self.window.contentView != inputView) {
		NSRect windowRect = self.window.frame;
		
		float newHeight = inputView.frame.size.height;
		int difference = newHeight - [self.window.contentView frame].size.height;
		windowRect.origin.y -= difference;
		windowRect.size.height += difference;
		
		difference = inputView.frame.size.width - [self.window.contentView frame].size.width;
		windowRect.origin.x -= difference/2;
		windowRect.size.width += difference;

		[inputView setHidden:YES];
		[self.window.contentView setHidden:YES];
		[self.window setContentView:inputView];
		[self.window setFrame:windowRect display:YES animate:YES];
		[inputView setHidden: NO];
	}
}

#pragma mark Pane:General Methods

-(IBAction)startChooseXML:(id)sender {
	NSOpenPanel * panel = [NSOpenPanel openPanel];
	[panel setAllowsMultipleSelection:NO];
	[panel setCanChooseDirectories:NO];

	[panel beginSheetForDirectory:[@"~/Music/iTunes/" stringByExpandingTildeInPath]
		file:@"iTunes Music Library.xml"
		types:[NSArray arrayWithObject:@"xml"]
		modalForWindow:self.window
		modalDelegate:self
		didEndSelector:@selector(filePanelDidEnd: returnCode: contextInfo:)
		contextInfo:nil];
}

-(void)filePanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	[panel orderOut:nil];
	if (returnCode == NSOKButton) {
		[[NSUserDefaults standardUserDefaults] setObject:[panel filename] forKey:BGPrefXmlLocation];
		[[NSNotificationCenter defaultCenter] postNotificationName:BGXmlLocationChangedNotification object:nil];
	}
}

-(IBAction)setLoginStart:(id)sender {
	NSString * appPath = [[NSBundle mainBundle] bundlePath];

	// This will retrieve the path for the application
	// For example, /Applications/test.app
	CFURLRef url = (CFURLRef)[NSURL fileURLWithPath:appPath];
	
	
	// Create a reference to the shared file list.
	LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL,
															kLSSharedFileListSessionLoginItems, NULL);

	if ([sender state] == NSOnState) {
		// add.
		
		if (loginItems) {
			//Insert an item to the list.
			LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(loginItems,
																		 kLSSharedFileListItemLast, NULL, NULL,
																		 url, NULL, NULL);
			if (item){
				CFRelease(item);
			}
		}
		CFRelease(loginItems);
	} else {
		// remove.
		
		if (loginItems) {
			UInt32 seedValue;
			//Retrieve the list of Login Items and cast them to
			// a NSArray so that it will be easier to iterate.
			NSArray  *loginItemsArray = (NSArray *)LSSharedFileListCopySnapshot(loginItems, &seedValue);
			int i;
			for(i = 0 ; i < [loginItemsArray count]; i++){
				LSSharedFileListItemRef itemRef = (LSSharedFileListItemRef)[loginItemsArray
																			objectAtIndex:i];
				//Resolve the item with URL
				if (LSSharedFileListItemResolve(itemRef, 0, (CFURLRef*) &url, NULL) == noErr) {
					NSString * urlPath = [(NSURL*)url path];
					if ([urlPath compare:appPath] == NSOrderedSame){
						LSSharedFileListItemRemove(loginItems,itemRef);
					}
				}
			}
			[loginItemsArray release];
		}
	}
}

-(IBAction)updateAutoDecision:(id)sender {
	[[NSNotificationCenter defaultCenter] postNotificationName:BGNotificationPodMounted object:nil];
}

#pragma mark Pane:LastFm Methods

-(IBAction)openLastFmWebsite:(id)sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.last.fm/join/"]];
}

-(IBAction)openAuthWebsite:(id)sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://www.last.fm/api/auth?api_key=%@",API_KEY]]];
}

-(void)loginProcessing {
	[NSThread detachNewThreadSelector:@selector(startAuthSpinner) toTarget:self withObject:nil];
}

-(void)startAuthSpinner {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[currentLoginContainer setHidden:NO];
	[authSpinner startAnimation:self];
	[pool release];
}

-(void)loginComplete {
	[authSpinner stopAnimation:self];
}

#pragma mark Pane:History Methods

- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex {
	return NO;
}

-(void)addHistoryWithSuccess:(BOOL)wasSuccess andDate:(NSDate *)aDate andDescription:(NSString *)aDescription {
	NSDictionary *theDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:wasSuccess],@"success",aDate,@"date",aDescription,@"comment",nil];
	NSMutableArray *newArray;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	newArray = [[defaults arrayForKey:@"ActivityHistory"] mutableCopy];
	if (!newArray) newArray = [NSMutableArray new];
	[newArray insertObject:theDict atIndex:0];
	
	int numberOfItems = newArray.count;
	if (numberOfItems>maxItems && maxItems<numberOfItems) {
		NSRange removeRange = NSMakeRange(maxItems,numberOfItems-maxItems);
		[newArray removeObjectsAtIndexes: [NSIndexSet indexSetWithIndexesInRange:removeRange] ];
	}
	
	[defaults setObject:newArray forKey:@"ActivityHistory"];
	[newArray release];
}

#pragma mark LoginItems
- (BOOL)loginItemExistsWithLoginItemReference:(LSSharedFileListRef)theLoginItemsRefs ForPath:(NSString *)appPath {
	BOOL found = NO;  
	UInt32 seedValue;
	CFURLRef thePath;
	
	// We're going to grab the contents of the shared file list (LSSharedFileListItemRef objects)
	// and pop it in an array so we can iterate through it to find our item.
	CFArrayRef loginItemsArray = LSSharedFileListCopySnapshot(theLoginItemsRefs, &seedValue);
	for (id item in (NSArray *)loginItemsArray) {
		LSSharedFileListItemRef itemRef = (LSSharedFileListItemRef)item;
		if (LSSharedFileListItemResolve(itemRef, 0, (CFURLRef*) &thePath, NULL) == noErr) {
			if ([[(NSURL *)thePath path] hasPrefix:appPath]) {
				found = YES;
				break;
			}
		}
		// Docs for LSSharedFileListItemResolve say we're responsible
		// for releasing the CFURLRef that is returned
		CFRelease(thePath);
	}
	CFRelease(loginItemsArray);
	
	return found;
}


@end