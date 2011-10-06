//
//  BGMultipleSongPlayManager.m
//  ScrobblePod
//
//  Created by Ben Gummer on 12/06/08.
//  Copyright 2008 Ben Gummer. All rights reserved.
//

#import "BGMultipleSongPlayManager.h"
#import "BGTimelineGap.h"

@implementation BGMultipleSongPlayManager

-(NSArray *)completeSongListForRecentTracks:(NSArray *)recentTracks sinceDate:(NSCalendarDate *)theDate {
	NSMutableDictionary *cachedDatabase = [[NSDictionary dictionaryWithContentsOfFile:[self pathForCachedDatabase]] mutableCopy];
	if (!cachedDatabase) cachedDatabase = [[NSMutableDictionary alloc] initWithCapacity:0]; // TODO: should BAIL if this is the case
	
	int lastScrobbleTime = [theDate timeIntervalSinceReferenceDate];
	
	// 2 lines below used for finding initial gaps
	int completionTimeOfPreviousSong = lastScrobbleTime;
	NSMutableArray *gapList = [[NSMutableArray alloc] initWithCapacity:10];
	
	BGLastFmSong *currentSong;
	for (currentSong in recentTracks) {
	
		NSString *currentPersistentIdentifier = currentSong.persistentIdentifier;
		int currentPlayCount = currentSong.playCount;
		int cachedPlayCount = [[cachedDatabase objectForKey:currentPersistentIdentifier] intValue];
		
        if (currentPlayCount) {
            if (!cachedPlayCount) cachedPlayCount = 0;
			int difference = currentPlayCount - cachedPlayCount;
			int extraPlays = difference - 1;
			DLog(@"PROCESSING SONG: '%@' (UID = %@) Cached:%d Current:%d CalculatedExtra:%d",currentSong.title,currentSong.persistentIdentifier, cachedPlayCount,currentPlayCount,extraPlays);
            if (extraPlays > 0) {
				currentSong.extraPlays = extraPlays;
				DLog(@"EXTRA PLAYS: '%@' = %d",currentSong.title,currentSong.extraPlays);
			}
		
            if (!currentPersistentIdentifier) { 
                DLog(@"WARNING: currentPersistentIdentifier = nil; will cause crash with setObject:forKey;");
            }
            
            // Crashing is not an option, is it?
            if (currentPersistentIdentifier) [cachedDatabase setObject:[NSNumber numberWithInt:currentPlayCount] forKey:currentPersistentIdentifier];
            
		} else {
			DLog(@"ASDBSDFSDFGSDAEWO! The song's play count is empty. Is it 2012 or what?");
		}

			
		// find extra plays
		int completionTimeOfCurrentSong = currentSong.unixPlayedDate;
		int startTimeOfCurrentSong = completionTimeOfCurrentSong - currentSong.length;

		if ( startTimeOfCurrentSong-completionTimeOfPreviousSong > 25) {
			BGTimelineGap *newGap = [[BGTimelineGap alloc] init];
			newGap.startTime = completionTimeOfPreviousSong;
			newGap.endTime = startTimeOfCurrentSong;
			DLog(@"FOUND GAP WITH DURATION: %d",newGap.duration);
			[gapList addObject:newGap];
			[newGap release];
		}
		completionTimeOfPreviousSong = completionTimeOfCurrentSong;

	}
	
	NSMutableArray *extraPlayCopies = [[NSMutableArray alloc] init];
	BOOL spotWasFound = YES;
	while (spotWasFound) {
		spotWasFound = NO;
		BOOL extraPlaysStillExist = NO;
		for (currentSong in recentTracks) {
			if (currentSong.extraPlays > 0) {
				extraPlaysStillExist = YES;
				//find spot
				NSMutableDictionary *closestMatch = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:-1],@"index",[NSNumber numberWithInt:-1],@"duration",nil];

				BGTimelineGap *currentGap;
				int i;
				for (i = 0; i < gapList.count; i++) {
					currentGap = [gapList objectAtIndex:i];
					int durationDifference = currentGap.duration - currentSong.length;
					int existingWinner = [[closestMatch objectForKey:@"duration"] intValue];
					// below: add 30 to the difference, so we allow for a bit of overlap
					if (durationDifference + 30 > 0 && (existingWinner < 0 || durationDifference < existingWinner)) { //  && currentGap.startTime < [currentSong.lastPlayed timeIntervalSinceReferenceDate]
						[closestMatch setObject:[NSNumber numberWithInt:i] forKey:@"index"];
						[closestMatch setObject:[NSNumber numberWithInt:durationDifference] forKey:@"duration"];
					}
				}
				
				int chosenGapIndex = [[closestMatch objectForKey:@"index"] intValue];
				if (chosenGapIndex > -1) {
					spotWasFound = YES;
					BGTimelineGap *chosenGap = [gapList objectAtIndex:chosenGapIndex];
					int chosenGapStartTime = chosenGap.startTime;
					//work out new date string
					int newSongCompletionTime = (chosenGapStartTime + currentSong.length);
					NSCalendarDate *newSongCompletionDate = [[NSCalendarDate alloc] initWithTimeIntervalSinceReferenceDate:newSongCompletionTime];
					BGLastFmSong *extraCopy = [currentSong copy];
					// At this point, extraCopy has isExtra set to yes, but also has extraPlays and a playCount. I think the scrobble math is wrong elsewhere.
					// i.e. if you play twice offline, we scrobble two objects 2 times, and overscrobble.
						[extraCopy setLastPlayed:newSongCompletionDate];
						[extraCopy setIsExtra:YES];
						[newSongCompletionDate release];
						[extraPlayCopies addObject:extraCopy];
					[extraCopy release];
					
					// update chosen gap to reflect its usage
					chosenGap.startTime = newSongCompletionTime;
					currentSong.extraPlays -= 1; // TODO: hack?
				} else {
					currentSong.extraPlays = 0; // TODO: hack?
				}
			}
		}
		
		if (extraPlaysStillExist == NO) spotWasFound = NO;
	}
	
	[gapList release];
	
	[cachedDatabase writeToFile:[self pathForCachedDatabase] atomically:YES]; // DISABLE TEMPORARILY SO THAT WE ACTUALLY HAVE SOME EXTRA PLAYS
	[cachedDatabase release];
	
	NSMutableArray *combinedArray = [NSMutableArray arrayWithCapacity:recentTracks.count + extraPlayCopies.count];
	
	[combinedArray addObjectsFromArray:recentTracks];
	[combinedArray addObjectsFromArray:extraPlayCopies];
	
	[extraPlayCopies release];
	
	NSArray *sortedArray = [combinedArray sortedArrayUsingSelector:@selector(compareLastPlayedDate:)];
	return sortedArray;
}

-(NSString *)pathForCachedDatabase { //Method from CocoaDevCentral.com
	NSFileManager *fileManager = [NSFileManager defaultManager];
    
	NSString *folder = @"~/Library/Application Support/ScrobblePod/";
	folder = [folder stringByExpandingTildeInPath];

	if ([fileManager fileExistsAtPath: folder] == NO) [fileManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
	
	NSString *fileName = @"PlayCountDB.xml";
	return [folder stringByAppendingPathComponent: fileName]; 
}

-(BOOL)cacheFileExists {
	return [[NSFileManager defaultManager] fileExistsAtPath:[self pathForCachedDatabase]];
}

@end

@implementation BGLastFmSong (CompareStringDates)

-(NSComparisonResult)compareLastPlayedDate:(BGLastFmSong *)comparisonItem {
    return ([self.lastPlayed compare:comparisonItem.lastPlayed]);
}

@end