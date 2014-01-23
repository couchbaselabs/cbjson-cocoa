//
//  CBIndexedJSONDict.h
//  CBJSON
//
//  Created by Jens Alfke on 12/30/13.
//  Copyright (c) 2013 Couchbase. All rights reserved.
//

#import <Foundation/Foundation.h>

/** An NSDictionary that reads directly from Indexed JSON without pre-parsing it. */
@interface CBIndexedJSONDict : NSDictionary

/** Creates an instance.
    @param indexedJSONData  Must be Indexed JSON or plain JSON data. If it's plain JSON, it will be parsed and a regular NSDictionary will be returned.
    @param dictToAdd  An optional dictionary of keys/values to add. Keys in this dictionary will override the corresponding keys in the Indexed JSON data.
    @param cacheValues  If YES, the value for a key will be cached after the first time it's parsed. This makes multiple accesses to the same key faster, at the expense of using more memory.
    @return  The dictionary, or nil if parsing failed. */
- (id) initWithData: (NSData*)indexedJSONData
                 addingValues: (NSDictionary*)dictToAdd
                  cacheValues: (BOOL)cacheValues;

/** Returns YES if the dictionary contains a value for the key.
    This is equivalent to `[dict objectForKey: key] != nil`, but faster because the value doesn't need to be parsed. */
- (BOOL)containsValueForKey:(NSString *)key;

/** The encoded Indexed JSON data of the dictionary (the same data that was given when initializing it.) */
@property (readonly) NSData* JSONData;

@end
