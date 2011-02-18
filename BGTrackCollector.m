//
//  BGTrackCollector.m
//  ScrobblePod
//
//  Created by Ben on 13/01/08.
//  Copyright 2008 Ben Gummer. All rights reserved.
//

#import "BGTrackCollector.h"
#import "BGLastFmSong.h"
#import "Defines.h"
//#import "NSDictionary+ExclusionTest.h"
#import <libxml/tree.h>
#import <libxml/parser.h>

// Function prototypes for SAX callbacks. 
static void startElementSAX (void * ctx, const xmlChar * fullname, const xmlChar ** atts);
static void	endElementSAX (void * ctx, const xmlChar * name);
static void	charactersFoundSAX(void * ctx, const xmlChar * ch, int len);
static void errorEncounteredSAX(void * ctx, const char * msg, ...);

// Forward reference. The structure is defined in full at the end of the file.
static xmlSAXHandler simpleSAXHandlerStruct;

@implementation BGTrackCollector

@synthesize  rssConnection, done, parsingASong, storingCharacters, currentSong, sillyCounter, countOfParsedSongs, characterBuffer, downloadAndParsePool, currentKeyString, cutoffDateInSeconds, wantedTracks, isValidTrack, scrobblePodcasts, scrobbleVideo, longerThan, commentToIgnore, genreToIgnore, parsingTracks;

- (void)dealloc {
	[rssConnection release];
    [wantedTracks release];
	[currentSong release];

	NSLog(@"BGTrackCollector deallocated!");
    [super dealloc];
}

-(NSMutableArray *)collectTracksFromXMLFile:(NSString *)xmlPath withCutoffDate:(NSDate *)cutoffDate includingPodcasts:(BOOL)includePodcasts includingVideo:(BOOL)includeVideo ignoringComment:(NSString *)ignoreString ignoringGenre:(NSString *)genreString withMinimumDuration:(int)minimumDuration {
		
	double oldPriority = [NSThread threadPriority];
	[NSThread setThreadPriority:0.0];
	
//	NSTimeInterval startTimeReference = [NSDate timeIntervalSinceReferenceDate];

	
    if (!xmlPath || ![[NSFileManager defaultManager] fileExistsAtPath:xmlPath]) {
		NSLog(@"Supplied XML path does not exist - Using default XML path");
		xmlPath = [@"~/Music/iTunes/iTunes Music Library.xml" stringByExpandingTildeInPath];
	}
    
   // [[NSURLCache sharedURLCache] removeAllCachedResponses];
	self.currentKeyString = [NSString string];
    NSURL *url = [NSURL fileURLWithPath:xmlPath];
//    NSLog(@"URL is: %@", url);
	
	
    
    self.downloadAndParsePool = [[NSAutoreleasePool alloc] init];

	
    done = NO;
    self.characterBuffer = [NSMutableData data];
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    NSURLRequest *theRequest = [NSURLRequest requestWithURL:url];
    // create the connection with the request and start loading the data
    rssConnection = [[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
	
    // This creates a context for "push" parsing in which chunks of data that are not "well balanced" can be passed
    // to the context for streaming parsing. The handler structure defined above will be used for all the parsing. 
    // The second argument, self, will be passed as user data to each of the SAX handlers. The last three arguments
    // are left blank to avoid creating a tree in memory.
	
    context = xmlCreatePushParserCtxt(&simpleSAXHandlerStruct, self, NULL, 0, NULL);
	
	
//	NSLog(@"%@", [cutoffDate descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S +0000" timeZone:nil locale:nil]);
    self.cutoffDateInSeconds = (double) [[NSDate dateWithString:[cutoffDate descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S +0000" timeZone:nil locale:nil]] timeIntervalSinceDate:[NSDate dateWithString:@"1904-01-01 00-00-00 +0000"]];
	self.scrobblePodcasts = includePodcasts;
	self.scrobbleVideo = includeVideo;
	self.longerThan = minimumDuration;
	self.commentToIgnore = ignoreString;
	self.genreToIgnore = genreString;
//	self.currentSong = [[[BGLastFmSong alloc] init] autorelease];
	//	NSLog(@"%f", self.cutoffDateInSeconds);
    self.wantedTracks = [NSMutableArray array];
    if (rssConnection != nil) {
        do {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        } while (!done);
    }
	

	
//	for (BGLastFmSong *song in wantedTracks)
//	{
		//	NSLog(@"%@", [song description]);
//	}
	
	NSSortDescriptor *d = [[[NSSortDescriptor alloc] initWithKey:@"lastPlayed" ascending: YES] autorelease];
	[wantedTracks sortUsingDescriptors:[NSArray arrayWithObject: d]];	
	
//	NSLog(@"Wanted Tracks Count: %u", [wantedTracks count]);
//	NSLog(@"Parsed Songs: %u", countOfParsedSongs);
    // Release resources used only in this thread.
    xmlFreeParserCtxt(context);
	
	self.commentToIgnore = nil;
	self.genreToIgnore = nil;
    self.characterBuffer = nil;
    self.rssConnection = nil;
    self.currentSong = nil;
    self.currentKeyString = nil;
	
    [downloadAndParsePool release];
    self.downloadAndParsePool = nil;
	
	
//	NSTimeInterval duration = [NSDate timeIntervalSinceReferenceDate] - startTimeReference;	
//	NSLog(@"%f", duration);

    
	[NSThread setThreadPriority:oldPriority];
	
	
    return wantedTracks;
}

#pragma mark NSURLConnection Delegate methods

/*
 Disable caching so that each time we run this app we are starting with a clean slate. You may not want to do this in your application.
 */

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse {
    return nil;
}

// Called when a chunk of data has been downloaded.
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    // Process the downloaded chunk of data.
	[[NSURLCache sharedURLCache] setMemoryCapacity:0];


    xmlParseChunk(context, (const char *)[data bytes], (int) [data length], 0);
	
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    // Signal the context that parsing is complete by passing "1" as the last parameter.
    // Set the condition which ends the run loop.
	
	// URL Cache trick
	NSURLCache *sharedCache = [[NSURLCache alloc] initWithMemoryCapacity:0 diskCapacity:0 diskPath:nil];
	[NSURLCache setSharedURLCache:sharedCache];
	[sharedCache release];

}

- (void)chunky;
{
	NSLog(@"Chunky!");
	xmlParseChunk(context, NULL, 0, 1);
	done = YES;
}

#pragma mark Parsing support methods

static const NSUInteger kAutoreleasePoolPurgeFrequency = 10;

- (void)finishedCurrentSong {
    // [self performSelectorOnMainThread:@selector(parsedSong:) withObject:currentSong waitUntilDone:NO];
    // performSelectorOnMainThread: will retain the object until the selector has been performed
    // setting the local reference to nil ensures that the local reference will be released
	//	[wantedTracks addObject:currentSong];
	//  self.currentSong = nil;
	
	//[[parser currentSong] release];
	
  //  countOfParsedSongs++;
    // Periodically purge the autorelease pool. The frequency of this action may need to be tuned according to the 
    // size of the objects being parsed. The goal is to keep the autorelease pool from growing too large, but 
    // taking this action too frequently would be wasteful and reduce performance.
 /*   if (countOfParsedSongs == kAutoreleasePoolPurgeFrequency) {
        [downloadAndParsePool release];
        self.downloadAndParsePool = [[NSAutoreleasePool alloc] init];
        countOfParsedSongs = 0;
    } */
}

/*
 Character data is appended to a buffer until the current element ends.
 */
- (void)appendCharacters:(const char *)charactersFound length:(NSInteger)length {
    [characterBuffer appendBytes:charactersFound length:length];
}

- (NSString *)currentString {
    // Create a string with the character data using UTF-8 encoding. UTF-8 is the default XML data encoding.
    NSString *currentString = [[[NSString alloc] initWithData:characterBuffer encoding:NSUTF8StringEncoding] autorelease];
    [characterBuffer setLength:0];
	//    if (sillyCounter < 100) {
	//        NSLog(@"%@", currentString);
	//        sillyCounter++;
	//    }
    return currentString;
}

@end

#pragma mark SAX Parsing Callbacks


// The following constants are the XML element names and their string lengths for parsing comparison.
// The lengths include the null terminator, to ensure exact matches.

// ! Здесь задаются строчки из XML
static const char *kName_Dict = "dict";
static const NSUInteger kLength_Dict = 5;
static const char *kName_Key = "key";
static const NSUInteger kLength_Key = 4;
static const char *kName_Integer = "integer";
static const NSUInteger kLength_Integer = 8;
static const char *kName_String = "string";
static const NSUInteger kLength_String = 7;
static const char *kName_Date = "date";
static const NSUInteger kLength_Date = 5;
static const char *kName_True = "true";
static const NSUInteger kLength_True = 5;

static NSString *kKey_Name = @"Name";
static NSString *kKey_Tracks = @"Tracks";
static NSString *kKey_Playlists = @"Playlists";
static NSString *kKey_Artist = @"Artist";
static NSString *kKey_Album = @"Album";
static NSString *kKey_Comment = @"Comments";
static NSString *kKey_Genre = @"Genre";
static NSString *kKey_PlayDate = @"Play Date";
static NSString *kKey_PlayDateUTC = @"Play Date UTC";
static NSString *kKey_Length = @"Total Time";
static NSString *kKey_PlayCount = @"Play Count";
static NSString *kKey_TrackID = @"Track ID";
static NSString *kKey_Podcast = @"Podcast";
static NSString *kKey_Video = @"Has Video";
static NSString *emptyString = @"";

// This callback is invoked when the parser finds the beginning of a node in the XML.
static void startElementSAX(void * ctx, const xmlChar * fullname, const xmlChar ** atts)
{
    BGTrackCollector *parser = (BGTrackCollector *)ctx;
    if (!strncmp((const char *)fullname, kName_Key, kLength_Key) || !strncmp((const char *)fullname, kName_Integer, kLength_Integer) || !strncmp((const char *)fullname, kName_String, kLength_String) || !strncmp((const char *)fullname, kName_Date, kLength_Date))
    {
        parser.storingCharacters = YES;
		//	NSLog(@"%@", ( parser.storingCharacters ? @"YES" : @"NO" ));
    }
    
}

// This callback is invoked when the parse reaches the end of a node.
static void	endElementSAX (void * ctx, const xmlChar * name) {
    BGTrackCollector *parser = (BGTrackCollector *)ctx;
	NSString *temporaryString = [[NSString alloc] initWithData:parser.characterBuffer encoding:NSUTF8StringEncoding];
    [parser.characterBuffer setLength:0];
//    NSString *temporaryString = [parser currentString];
	if (!strncmp((const char *)name, kName_Key, kLength_Key)) 
    {
        parser.storingCharacters = NO;
		if ([temporaryString isEqualToString:kKey_Tracks])
		{
			parser.parsingTracks = YES;
		}
		else if([temporaryString isEqualToString:kKey_Playlists] && parser.parsingTracks)
		{
			parser.parsingTracks = NO;
			parser.done = YES;
			parser.currentKeyString = emptyString;
			parser.isValidTrack = NO;
		}
        else if ([temporaryString isEqualToString:kKey_TrackID] && parser.parsingTracks) 
		{
			BGLastFmSong *newSong = [[BGLastFmSong alloc] init];
			parser.currentSong = newSong;
			[newSong release];
			parser.isValidTrack = NO;
			parser.parsingASong = YES;
			parser.currentKeyString = temporaryString;
			parser.countOfParsedSongs++;
        }
		else if (([temporaryString isEqualToString:kKey_Name] || [temporaryString isEqualToString:kKey_Artist] || [temporaryString isEqualToString:kKey_Album] || [temporaryString isEqualToString:kKey_Comment] || [temporaryString isEqualToString:kKey_Genre] || [temporaryString isEqualToString:kKey_PlayDate] || [temporaryString isEqualToString:kKey_PlayDateUTC] || [temporaryString isEqualToString:kKey_Length] || [temporaryString isEqualToString:kKey_PlayCount] || [temporaryString isEqualToString:kKey_Comment] || [temporaryString isEqualToString:kKey_Podcast] || [temporaryString isEqualToString:kKey_Video])  && parser.parsingTracks)
		{
			parser.currentKeyString = temporaryString;
			//	NSLog(@"%@", parser.currentKeyString);
		}
		
		//	if (![parser.currentKeyString isEqualToString:emptyString])
		//		NSLog(@"%@", parser.currentKeyString);
	} 
	else if (!strncmp((const char *)name, kName_True, kLength_True) && parser.parsingTracks)
    {
		parser.storingCharacters = NO;
		if ([parser.currentKeyString isEqualToString:kKey_Podcast] && parser.scrobblePodcasts == YES)
		{
			parser.isValidTrack = YES;
		}
		else if ([parser.currentKeyString isEqualToString:kKey_Video] && parser.scrobbleVideo == YES)
		{
			parser.isValidTrack = YES;
		}
		parser.currentKeyString = emptyString;
    }
	else if (!strncmp((const char *)name, kName_Integer, kLength_Integer) && ![parser.currentKeyString isEqualToString:emptyString]  && parser.parsingTracks == YES)
	{
		//	NSLog(@"'%@'", temporaryString);
		parser.storingCharacters = NO;
		if ([parser.currentKeyString isEqualToString:kKey_TrackID])
		{
			parser.currentSong.uniqueIdentifier = temporaryString;
		}
		else if ([parser.currentKeyString isEqualToString:kKey_Length])
		{
			
			parser.currentSong.length = [temporaryString intValue] / 1000;
		}
		else if ([parser.currentKeyString isEqualToString:kKey_PlayCount])
		{
			parser.currentSong.playCount = [temporaryString intValue];
		}
		else if ([parser.currentKeyString isEqualToString:kKey_PlayDate])
		{
			//	NSLog(@"%.0f — song",[temporaryString doubleValue]);
			//	NSLog(@"%.0f", parser.cutoffDateInSeconds);
			if ([temporaryString doubleValue] > parser.cutoffDateInSeconds)
			{
				parser.isValidTrack = YES;
				parser.currentSong.lastPlayed = [[[NSDate dateWithString:@"1904-01-01 00-00-00 +0000"] dateByAddingTimeInterval:[temporaryString doubleValue]] dateWithCalendarFormat:@"%Y-%m-%d %H:%M:%S" timeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
				
			//	NSLog(@"%@",[[[NSDate dateWithString:@"1904-01-01 00-00-00 +0000"] dateByAddingTimeInterval:[temporaryString doubleValue]] dateWithCalendarFormat:nil timeZone:[NSTimeZone timeZoneWithName:@"UTC"]]);
			}
		}
		
		//	NSLog(@"%@", (parser.isValidTrack ? @"VALID" : @"NOT VALID"));
		parser.currentKeyString = emptyString;
	}
	else if (!strncmp((const char *)name, kName_String, kLength_String) && ![parser.currentKeyString isEqualToString:emptyString]  && parser.parsingTracks)
	{
		parser.storingCharacters = NO;
		if ([parser.currentKeyString isEqual:kKey_Name])
		{
			parser.currentSong.title = temporaryString;
		}
		else if ([parser.currentKeyString isEqual:kKey_Artist])
		{
			[[parser currentSong] setArtist:temporaryString];
		}
		else if ([parser.currentKeyString isEqualToString:kKey_Album])
		{
			[[parser currentSong] setAlbum:temporaryString];
		}
		else if ([parser.currentKeyString isEqualToString:kKey_Genre])
		{
			if ([temporaryString isEqualToString:[parser genreToIgnore]])
			{
				parser.isValidTrack = NO;
			}
			[[parser currentSong] setGenre:temporaryString];
		}
		else if ([parser.currentKeyString isEqualToString:kKey_Comment])
		{
			if ([temporaryString isEqualToString:[parser commentToIgnore]])
			{
				parser.isValidTrack = NO;
			}
			[[parser currentSong] setComment:temporaryString];
		}
		else if ([parser.currentKeyString isEqual:kKey_Podcast])
		{
			//	NSLog(@"%@", temporaryString);
		}
		else if ([parser.currentKeyString isEqualToString:kKey_Video])
		{
			//	NSLog(@"%@", temporaryString);
		}
		parser.currentKeyString = emptyString;
	}
	else if (!strncmp((const char *)name, kName_Date, kLength_Date)  && parser.parsingTracks)
	{
		parser.storingCharacters = NO;
		/*	if ([parser.currentKeyString isEqualToString:kKey_PlayDateUTC] && parser.isValidTrack == YES)
		 {
		 //		NSLog(@"%@", temporaryString);
		 NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
		 [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
		 parser.currentSong.lastPlayed = [NSCalendarDate dateWithString:[[dateFormatter dateFromString:temporaryString] descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S" timeZone:nil locale:nil] calendarFormat:@"%Y-%m-%d %H:%M:%S"];
		 [dateFormatter release];
		 } */
		parser.currentKeyString = emptyString;
	}
	else if (!strncmp((const char *)name, kName_Dict, kLength_Dict)  && parser.parsingTracks)
    {
		//	NSLog(@"C: %.0f", parser.cutoffDateInSeconds);
		//NSLog(@"Song description: %@", [[parser currentSong] description]);
		//	NSLog(@"-----------------------");
		//	parser.storingCharacters = NO;
        if (parser.parsingASong && parser.parsingTracks == YES)
            parser.parsingASong = NO;
		
		if (parser.isValidTrack == YES && parser.parsingTracks == YES && parser.currentSong.lastPlayed != NULL) {
			//[parser finishedCurrentSong];
			//	NSLog(@"Valid song!");
			//	NSLog(@"%@", (parser.isValidTrack ? @"VALID" : @"NOT VALID"));
			//	NSLog(@"%@", parser.currentSong.title);
			[parser.wantedTracks addObject:parser.currentSong];

		}
		//[parser finishedCurrentSong];
		parser.currentKeyString = emptyString;
    }
	else {
		parser.storingCharacters = NO;
	}
	[temporaryString release];
}

/*
 This callback is invoked when the parser encounters character data inside a node. The parser class determines how to use the character data.
 */
static void	charactersFoundSAX(void *ctx, const xmlChar *ch, int len) {
    BGTrackCollector *parser = (BGTrackCollector *)ctx;
    if (parser.storingCharacters == NO) return;
    [parser appendCharacters:(const char *)ch length:len];
}

/*
 A production application should include robust error handling as part of its parsing implementation.
 The specifics of how errors are handled depends on the application.
 */
static void errorEncounteredSAX(void *ctx, const char *msg, ...) {
    // Handle errors as appropriate for your application.
    NSCAssert(NO, @"Unhandled error encountered during SAX parse.");
}

// The handler struct has positions for a large number of callback functions. If NULL is supplied at a given position,
// that callback functionality won't be used. Refer to libxml documentation at http://www.xmlsoft.org for more information
// about the SAX callbacks.
static xmlSAXHandler simpleSAXHandlerStruct = {
    NULL,                       /* internalSubset */
    NULL,                       /* isStandalone   */
    NULL,                       /* hasInternalSubset */
    NULL,                       /* hasExternalSubset */
    NULL,                       /* resolveEntity */
    NULL,                       /* getEntity */
    NULL,                       /* entityDecl */
    NULL,                       /* notationDecl */
    NULL,                       /* attributeDecl */
    NULL,                       /* elementDecl */
    NULL,                       /* unparsedEntityDecl */
    NULL,                       /* setDocumentLocator */
    NULL,                       /* startDocument */
    NULL,                       /* endDocument */
    startElementSAX,            /* startElement*/
    endElementSAX,              /* endElement */
    NULL,                       /* reference */
    charactersFoundSAX,         /* characters */
    NULL,                       /* ignorableWhitespace */
    NULL,                       /* processingInstruction */
    NULL,                       /* comment */
    NULL,                       /* warning */
    errorEncounteredSAX,        /* error */
    NULL,                       /* fatalError //: unused error() get all the errors */
    NULL,                       /* getParameterEntity */
    NULL,                       /* cdataBlock */
    NULL,                       /* externalSubset */
    XML_SAX2_MAGIC,             //
    NULL,
    NULL,            /* startElementNs */
    NULL,              /* endElementNs */
    NULL,                       /* serror */
};