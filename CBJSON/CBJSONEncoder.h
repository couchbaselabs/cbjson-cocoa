//
//  CBJSONEncoder.h
//  CBJSON
//
//  Created by Jens Alfke on 12/27/13.
//  Copyright (c) 2013 Couchbase. All rights reserved.
//

#import <Foundation/Foundation.h>

/** Encodes Cocoa objects to JSON. */
@interface CBJSONEncoder : NSObject

- (instancetype) init;

- (BOOL) encode: (id)object;

@property (readonly, nonatomic) NSError* error;
@property (readonly, nonatomic) NSData* encodedData;

+ (NSData*) encode: (id)object error: (NSError**)outError;


// PROTECTED:
@property (readonly, nonatomic) NSMutableData* output;
- (BOOL) encodeKey: (id)key value: (id)value;
- (BOOL) encodeNestedObject: (id)object;

+ (BOOL) string: (NSString*)str processBytes: (void (^)(const char*, size_t))block;

@end
