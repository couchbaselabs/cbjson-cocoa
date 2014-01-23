//
//  CBIndexedJSONEncoder.h
//  CBJSON
//
//  Created by Jens Alfke on 12/27/13.
//  Copyright (c) 2013 Couchbase. All rights reserved.
//

#import "CBJSONEncoder.h"

/** Encodes Cocoa objects to Indexed JSON. */
@interface CBIndexedJSONEncoder : CBJSONEncoder

+ (BOOL) isValidIndexedJSON: (NSData*)data;

+ (UInt16) indexHash: (NSString*)key;

@end
