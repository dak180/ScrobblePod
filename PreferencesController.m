#import "PreferencesController.h"
#import "SFHFKeychainUtils.h"
#import "Defines.h"
#import "iPodWatcher.h"
#import <Security/Security.h>
#import <QuartzCore/CoreAnimation.h>
#import "HubStrings.h"
#import "HubNotifications.h"

#define maxItems 10 // Cutoff for history items

static void loginItemsChanged(LSSharedFileListRef listRef, void *context);

@implementation PreferencesController

@synthesize launchOnLogin;

#pragma mark WindowController Methods

- (id) init {
	if (!(self = [super initWithWindowNibName:@"Preferences"]))
		return nil;
	
	loginItemsListRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
	seedValue = LSSharedFileListGetSeedValue(loginItemsListRef);
	
	if (loginItemsListRef)
		LSSharedFileListAddObserver(loginItemsListRef, CFRunLoopGetMain(), kCFRunLoopCommonModes,loginItemsChanged, self);
	
	return self;
}

- (void) dealloc
{
	if (loginItemsListRef)
		CFRelease(loginItemsListRef);

	[super dealloc];
}

- (void)windowDidLoad {
//	[self.window setLevel:NSModalPanelWindowLevel]; // Disabled since 0.51 preview 3
	[self.window center];
	[self.window setShowsToolbarButton:NO];
	
	NSImageCell *theCell = [[NSImageCell alloc] init];
	[historyIconTableColumn setDataCell:theCell];
	[theCell release];
		
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
	//	[prefToolbar setVisible:NO];
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
	[pool drain];
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

- (NSArray *)loginItems
{
    CFArrayRef snapshotRef = LSSharedFileListCopySnapshot(loginItemsListRef, &seedValue);
    return [NSMakeCollectable(snapshotRef) autorelease];
}

- (LSSharedFileListItemRef)mainBundleLoginItemCopy
{
    NSArray *loginItems = [self loginItems];
    NSURL *bundleURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
    
    for (id item in loginItems) {
        LSSharedFileListItemRef itemRef = (LSSharedFileListItemRef)item;
        CFURLRef itemURLRef;
        
        if (LSSharedFileListItemResolve(itemRef, 0, &itemURLRef, NULL) == noErr) {
            NSURL *itemURL = (NSURL *)[NSMakeCollectable(itemURLRef) autorelease];
            if ([itemURL isEqual:bundleURL]) {
                CFRetain(item);
                return (LSSharedFileListItemRef)item;
            }
        }
    }
    
    return NULL;
}

- (void)addMainBundleToLoginItems;
{
    NSURL *bundleURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
    NSDictionary *properties = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"com.apple.loginitem.HideOnLaunch"];
    LSSharedFileListItemRef itemRef;
    itemRef = LSSharedFileListInsertItemURL(loginItemsListRef, kLSSharedFileListItemLast, NULL, NULL, (CFURLRef)bundleURL, (CFDictionaryRef)properties, NULL);
	
    if (itemRef)
		CFRelease(itemRef);
}

- (void)removeMainBundleFromLoginItems;
{
    LSSharedFileListItemRef itemRef = [self mainBundleLoginItemCopy];
	
    if (!itemRef)
        return;
    
    LSSharedFileListItemRemove(loginItemsListRef, itemRef);
    
    CFRelease(itemRef);
}

- (BOOL)launchOnLogin;
{
    if (!loginItemsListRef)
        return NO;
	
    LSSharedFileListItemRef itemRef = [self mainBundleLoginItemCopy];    
    if (!itemRef)
        return NO;
    
    CFRelease(itemRef);
    return YES;
}

- (void)setLaunchOnLogin:(BOOL)value;
{
    if (!loginItemsListRef)
        return;
    
    if (!value) {
        [self removeMainBundleFromLoginItems];
    } else {
        [self addMainBundleToLoginItems];
    }
}

- (UInt32)launchOnLoginSeedValue;
{
	return seedValue;
}

@end

static void loginItemsChanged(LSSharedFileListRef listRef, void *context)
{	
    PreferencesController *controller = context;
	
	if ([controller launchOnLoginSeedValue] == LSSharedFileListGetSeedValue(listRef))
		return;
	
    [controller willChangeValueForKey:@"launchOnLogin"];
    [controller didChangeValueForKey:@"launchOnLogin"];
}