//
//  BGTrackCollector.h
//  ScrobblePod
//
//  Created by Ben on 13/01/08.
//  Copyright 2008 Ben Gummer. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <libxml/tree.h>
#import "BGLastFmSong.h"

@class BGLastFmSong, BGTrackCollector;

@interface BGTrackCollector : NSObject {
	NSMutableArray *wantedTracks;
@private
    // Reference to the libxml parser context
    xmlParserCtxtPtr context;
    NSURLConnection *rssConnection;
    // Overall state of the parser, used to exit the run loop.
    BOOL done;
    // State variable used to determine whether or not to ignore a given XML element
    BOOL parsingASong;
    // The following state variables deal with getting character data from XML elements. This is a potentially expensive 
    // operation. The character data in a given element may be delivered over the course of multiple callbacks, so that
    // data must be appended to a buffer. The optimal way of doing this is to use a C string buffer that grows exponentially.
    // When all the characters have been delivered, an NSString is constructed and the buffer is reset.
    BOOL storingCharacters;
	BOOL scrobblePodcasts;
	BOOL scrobbleVideo;
	BOOL isValidTrack;
	int longerThan;
	BOOL parsingTracks;
	NSString *commentToIgnore;
	NSString *genreToIgnore;
	NSString *currentKeyString;
    NSMutableData *characterBuffer;
    // A reference to the current song the parser is working with.
    BGLastFmSong *currentSong;
	double cutoffDateInSeconds;
    // The number of parsed songs is tracked so that the autorelease pool for the parsing thread can be periodically
    // emptied to keep the memory footprint under control.
    NSUInteger sillyCounter;
    NSUInteger countOfParsedSongs;
    NSAutoreleasePool *downloadAndParsePool;
    NSDateFormatter *parseFormatter;
	
}

//@property (nonatomic, retain) NSMutableArray *parsedSongs;
// new parser properties
@property BOOL storingCharacters;
@property (nonatomic, retain) NSMutableData *characterBuffer;
@property BOOL done;
@property BOOL parsingASong;
// Track validation
@property BOOL isValidTrack;
@property BOOL scrobblePodcasts;
@property BOOL scrobbleVideo;
@property BOOL parsingTracks;
@property int longerThan;
@property (nonatomic, retain) NSString *commentToIgnore;
@property (nonatomic, retain) NSString *genreToIgnore;

@property NSUInteger countOfParsedSongs;
@property NSUInteger sillyCounter;
@property double cutoffDateInSeconds;
@property (nonatomic, retain) NSString *currentKeyString;
@property (nonatomic, retain) NSMutableArray *wantedTracks;
@property (nonatomic, retain) BGLastFmSong *currentSong;
@property (nonatomic, retain) NSURLConnection *rssConnection;
@property (nonatomic, retain) NSDateFormatter *parseFormatter;
// The autorelease pool property is assign because autorelease pools cannot be retained.
@property (nonatomic, assign) NSAutoreleasePool *downloadAndParsePool;

-(NSMutableArray *)collectTracksFromXMLFile:(NSString *)xmlPath withCutoffDate:(NSDate *)cutoffDate includingPodcasts:(BOOL)includePodcasts includingVideo:(BOOL)includeVideo ignoringComment:(NSString *)ignoreString ignoringGenre:(NSString *)genreString withMinimumDuration:(int)minimumDuration;
- (void)finishedCurrentSong;
- (NSString *)currentString;
@end
