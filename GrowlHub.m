//
//  GrowlHub.m
//  ScrobblePod
//
//  Created by Ben Gummer on 22/05/08.
//  Copyright 2008 Ben Gummer. All rights reserved.
//

#import "GrowlHub.h"
#import "Defines.h"

static GrowlHub *sharedGrowlHub = nil;

@implementation GrowlHub

+(GrowlHub *)sharedManager {
    @synchronized(self) {
        if (sharedGrowlHub == nil) {
            [[self alloc] init]; // Assignment not done here
        }
    }
    return sharedGrowlHub;
}

+(id)allocWithZone:(NSZone *)zone {
    @synchronized(self) {
        if (sharedGrowlHub == nil) {
            sharedGrowlHub = [super allocWithZone:zone];
            return sharedGrowlHub; // Assignment and return on first allocation
        }
    }
	return nil; // On subsequent allocation attempts return nil
}

-(id)copyWithZone:(NSZone *)zone {
	return self;
}

-(id)retain {
	return self;
}

- (unsigned)retainCount {
	return NSUIntegerMax; // Denotes an object that cannot be released
}
 
-(void)release {
	// Do nothing
}
 
-(id)autorelease {
	return self;
}

-(id)init {
	if (!(self = [super init])) 
		return nil;
    
    sharedGrowlHub = self;
    [GrowlApplicationBridge setGrowlDelegate:self];
	return self;
}

-(NSDictionary *)registrationDictionaryForGrowl {
	NSArray *growlNotifications = [NSArray arrayWithObjects:SP_Growl_StartedScrobbling,
														   SP_Growl_FinishedScrobbling,
														     SP_Growl_FailedScrobbling,
															     SP_Growl_TrackChanged,
															  SP_Growl_DecisionChanged,
															    SP_Growl_LoginComplete, nil];
	return [NSDictionary dictionaryWithObjectsAndKeys:growlNotifications, GROWL_NOTIFICATIONS_ALL, growlNotifications, GROWL_NOTIFICATIONS_DEFAULT, nil];
}

-(void)postGrowlNotificationWithName:(NSString *)postName andTitle:(NSString *)postTitle andDescription:(NSString *)postDescription andImage:(NSData *)postImage andIdentifier:(NSString *)postIdentifier {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	BOOL shouldPost = NO;
	if ([postName isEqualToString:SP_Growl_TrackChanged]) {
		shouldPost = [defaults boolForKey:BGPref_Growl_SongChange];
	} else if ([postName isEqualToString:SP_Growl_DecisionChanged]) {
		shouldPost = [defaults boolForKey:BGPref_Growl_ScrobbleDecisionChanged];
	} else if ([postName isEqualToString:SP_Growl_StartedScrobbling] || [postName isEqualToString:SP_Growl_FinishedScrobbling] || [postName isEqualToString:SP_Growl_FailedScrobbling]) {
		shouldPost = [defaults boolForKey:BGPref_Growl_ScrobbleFail];
	} else if ([postName isEqualToString:SP_Growl_LoginComplete]) {
		shouldPost = YES;
	}
	
	if (shouldPost) [GrowlApplicationBridge notifyWithTitle:postTitle description:postDescription notificationName:postName iconData:postImage priority:0 isSticky:NO clickContext:nil identifier:postIdentifier];
}

@end
