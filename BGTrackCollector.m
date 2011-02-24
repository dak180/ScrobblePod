//
//  BGTrackCollector.m
//  ScrobblePod
//
//  Created by Ben Gummer on 13/01/08.
//	Edited by Anton Sotkov on 15/02/11.
//

#import "BGTrackCollector.h"
#import "BGLastFmSong.h"
#import "Defines.h"
#import <libxml/tree.h>
#import <libxml/parser.h>
#import "NSString+Contains.h"

static void startElementSAX (void * ctx, const xmlChar * fullname, const xmlChar ** atts);
static void	endElementSAX (void * ctx, const xmlChar * name);
static void	charactersFoundSAX(void * ctx, const xmlChar * ch, int len);
static void errorEncounteredSAX(void * ctx, const char * msg, ...);
static xmlSAXHandler simpleSAXHandlerStruct;

@implementation BGTrackCollector

@synthesize rssConnection, done, parsingASong, storingCharacters, currentSong, sillyCounter, countOfParsedSongs, characterBuffer, downloadAndParsePool, currentKeyString, cutoffDateInSeconds, wantedTracks, isValidTrack, scrobblePodcasts, scrobbleVideo, longerThan, commentToIgnore, genreToIgnore, parsingTracks;

- (void)dealloc {
	[rssConnection release];
    [super dealloc];
}

-(NSMutableArray *)collectTracksFromXMLFile:(NSString *)xmlPath withCutoffDate:(NSDate *)cutoffDate includingPodcasts:(BOOL)includePodcasts includingVideo:(BOOL)includeVideo ignoringComment:(NSString *)ignoreString ignoringGenre:(NSString *)genreString withMinimumDuration:(int)minimumDuration; 
{
	double oldPriority = [NSThread threadPriority];
	[NSThread setThreadPriority:0.0];
	self.downloadAndParsePool = [[NSAutoreleasePool alloc] init];
//	NSTimeInterval startTimeReference = [NSDate timeIntervalSinceReferenceDate];

    if (!xmlPath || ![[NSFileManager defaultManager] fileExistsAtPath:xmlPath]) {
		NSLog(@"Supplied XML path does not exist - Using default XML path");
		xmlPath = [@"~/Music/iTunes/iTunes Music Library.xml" stringByExpandingTildeInPath];
	}
    
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
	self.currentKeyString = [NSString string];
    NSURL *url = [NSURL fileURLWithPath:xmlPath];
    done = NO;
    self.characterBuffer = [NSMutableData data];
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    NSURLRequest *theRequest = [NSURLRequest requestWithURL:url];
    rssConnection = [[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
    context = xmlCreatePushParserCtxt(&simpleSAXHandlerStruct, self, NULL, 0, NULL);
	// http://cl.ly/1K2P0k1L2C1U0e0L0o1D
	// First number is a time interval from 01.01.1904 to 01.01.2001
	self.cutoffDateInSeconds = 3061159200.0 + [cutoffDate timeIntervalSinceReferenceDate];
	self.scrobblePodcasts = includePodcasts;
	self.scrobbleVideo = includeVideo;
	self.longerThan = minimumDuration;
	self.commentToIgnore = ignoreString;
	self.genreToIgnore = genreString;
    self.wantedTracks = [NSMutableArray array];
	
    if (rssConnection != nil) 
	{
        do {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        } while (!done);
    }
	
	NSSortDescriptor *d = [[[NSSortDescriptor alloc] initWithKey:@"lastPlayed" ascending: YES] autorelease];
	[wantedTracks sortUsingDescriptors:[NSArray arrayWithObject: d]];
    xmlFreeParserCtxt(context);
	theRequest = nil;
	self.commentToIgnore = nil;
	self.genreToIgnore = nil;
    self.characterBuffer = nil;
    self.rssConnection = nil;
    self.currentSong = nil;
    self.currentKeyString = nil;
    [downloadAndParsePool drain];
    self.downloadAndParsePool = nil;
//	NSTimeInterval duration = [NSDate timeIntervalSinceReferenceDate] - startTimeReference;	
//	NSLog(@"%f", duration);
	[NSThread setThreadPriority:oldPriority];
    return wantedTracks;
}

#pragma mark NSURLConnection Delegate methods

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse {
    return nil;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    xmlParseChunk(context, (const char *)[data bytes], (int) [data length], 0);
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {	
	// URL Cache trick
	NSURLCache *sharedCache = [[NSURLCache alloc] initWithMemoryCapacity:0 diskCapacity:0 diskPath:nil];
	[NSURLCache setSharedURLCache:sharedCache];
	[sharedCache release];

	xmlParseChunk(context, NULL, 0, 1);
	done = YES;
	
}

#pragma mark Parsing support methods

static const NSUInteger kAutoreleasePoolPurgeFrequency = 50;

- (void)appendCharacters:(const char *)charactersFound length:(NSInteger)length {
    [characterBuffer appendBytes:charactersFound length:length];
}

- (NSString *)currentString {
    // Create a string with the character data using UTF-8 encoding. UTF-8 is the default XML data encoding.
    NSString *currentString = [[[NSString alloc] initWithData:characterBuffer encoding:NSUTF8StringEncoding] autorelease];
    [characterBuffer setLength:0];
    return currentString;
}

@end

#pragma mark SAX Parsing Callbacks

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

static void startElementSAX(void * ctx, const xmlChar * fullname, const xmlChar ** atts)
{
    BGTrackCollector *parser = (BGTrackCollector *)ctx;
    if (!strncmp((const char *)fullname, kName_Key, kLength_Key) || !strncmp((const char *)fullname, kName_Integer, kLength_Integer) || !strncmp((const char *)fullname, kName_String, kLength_String) || !strncmp((const char *)fullname, kName_Date, kLength_Date))
    {
        parser.storingCharacters = YES;
    }
}

static void	endElementSAX (void * ctx, const xmlChar * name) {
    BGTrackCollector *parser = (BGTrackCollector *)ctx;
	NSString *temporaryString = [[NSString alloc] initWithData:parser.characterBuffer encoding:NSUTF8StringEncoding];
    [parser.characterBuffer setLength:0];
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
			parser.currentKeyString = emptyString;
			parser.isValidTrack = NO;
		}
        else if ([temporaryString isEqualToString:kKey_TrackID] && parser.parsingTracks) 
		{
			BGLastFmSong *newSong = [[BGLastFmSong alloc] init];
			parser.currentSong = newSong;
			[newSong release];
			parser.isValidTrack = YES;
			parser.parsingASong = YES;
			parser.currentKeyString = temporaryString;
		//	parser.countOfParsedSongs++;
        }
		else if (([temporaryString isEqualToString:kKey_Name] || [temporaryString isEqualToString:kKey_Artist] || [temporaryString isEqualToString:kKey_Album] || [temporaryString isEqualToString:kKey_Comment] || [temporaryString isEqualToString:kKey_Genre] || [temporaryString isEqualToString:kKey_PlayDate] || [temporaryString isEqualToString:kKey_PlayDateUTC] || [temporaryString isEqualToString:kKey_Length] || [temporaryString isEqualToString:kKey_PlayCount] || [temporaryString isEqualToString:kKey_Comment] || [temporaryString isEqualToString:kKey_Podcast] || [temporaryString isEqualToString:kKey_Video])  && parser.parsingTracks)
		{
			parser.currentKeyString = temporaryString;
		}
	}
	else if (!strncmp((const char *)name, kName_True, kLength_True) && parser.parsingTracks)
    {
		parser.storingCharacters = NO;
		if ([parser.currentKeyString isEqualToString:kKey_Podcast] && parser.scrobblePodcasts == NO)
		{
			parser.isValidTrack = NO;
		}
		else if ([parser.currentKeyString isEqualToString:kKey_Video] && parser.scrobbleVideo == NO)
		{
			parser.isValidTrack = NO;
		}
		parser.currentKeyString = emptyString;
    }
	else if (!strncmp((const char *)name, kName_Integer, kLength_Integer) && parser.storingCharacters && parser.parsingTracks)
	{
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
			if ([temporaryString doubleValue] < parser.cutoffDateInSeconds)
			{
				parser.isValidTrack = NO;
			}
			parser.currentSong.lastPlayed = [[NSDate dateWithTimeIntervalSinceReferenceDate:([temporaryString doubleValue] - 3061159200.0)] dateWithCalendarFormat:@"%Y-%m-%d %H:%M:%S" timeZone:[NSTimeZone systemTimeZone]];
		}
		
		//	NSLog(@"%@", (parser.isValidTrack ? @"VALID" : @"NOT VALID"));
		parser.currentKeyString = emptyString;
	}
	else if (!strncmp((const char *)name, kName_String, kLength_String) && ![parser.currentKeyString isEqualToString:emptyString]  && parser.parsingTracks  && parser.storingCharacters)
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
			if ((parser.genreToIgnore != nil) && [temporaryString isEqualToString:[parser genreToIgnore]])
			{
				parser.isValidTrack = NO;
			}
			[[parser currentSong] setGenre:temporaryString];
		}
		else if ([parser.currentKeyString isEqualToString:kKey_Comment])
		{
			if ((parser.commentToIgnore != nil) && [temporaryString containsString:[parser commentToIgnore]])
			{
				parser.isValidTrack = NO;
			}
			[[parser currentSong] setComment:temporaryString];
		}
		else if ([parser.currentKeyString isEqual:kKey_Podcast])
		{
		}
		else if ([parser.currentKeyString isEqualToString:kKey_Video])
		{
		}
		parser.currentKeyString = emptyString;

	}
	else if (!strncmp((const char *)name, kName_Date, kLength_Date)  && parser.parsingTracks && parser.storingCharacters)
	{
		parser.storingCharacters = NO;
		parser.currentKeyString = emptyString;
	}
	else if (!strncmp((const char *)name, kName_Dict, kLength_Dict)  && parser.parsingTracks)
    {
		parser.storingCharacters = NO;
        if (parser.parsingASong && parser.parsingTracks == YES)
            parser.parsingASong = NO;
		
		if (parser.isValidTrack == YES && parser.parsingTracks == YES && parser.currentSong.lastPlayed != NULL) {
			[parser.wantedTracks addObject:parser.currentSong];

		}
		parser.currentKeyString = emptyString;
    }
	else {
		parser.storingCharacters = NO;
		parser.currentKeyString = emptyString;	
	}
	[temporaryString release];
}

static void	charactersFoundSAX(void *ctx, const xmlChar *ch, int len) {
    BGTrackCollector *parser = (BGTrackCollector *)ctx;
    if (parser.storingCharacters == NO) return;
    [parser appendCharacters:(const char *)ch length:len];
}

static void errorEncounteredSAX(void *ctx, const char *msg, ...) {
    NSCAssert(NO, @"Unhandled error encountered during SAX parse.");
}

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