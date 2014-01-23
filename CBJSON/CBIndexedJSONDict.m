//
//  CBIndexedJSONDict.m
//  CBJSON
//
//  Created by Jens Alfke on 12/30/13.
//  Copyright (c) 2013 Couchbase. All rights reserved.
//

#import "CBIndexedJSONDict.h"
#import "CBIndexedJSONEncoder.h"
#import "CBIndexedJSONFormat.h"


@implementation CBIndexedJSONDict
{
    const DictHeader* _header;
    NSData* _data;
    const uint8_t* _json;
    NSMutableDictionary* _cache;
    BOOL _hasAddedValues;
    BOOL _addToCache;
    NSUInteger _count;
}


- (id) initWithData: (NSData*)indexedJSONData
                 addingValues: (NSDictionary*)dictToAdd
                  cacheValues: (BOOL)cacheValues
{
    NSParameterAssert(indexedJSONData);
    self = [super init];
    if (self) {
        if (![CBIndexedJSONEncoder isValidIndexedJSON: indexedJSONData]) {
            // If this is regular ol' JSON, fall back to NSJSONSerialization:
            if (indexedJSONData.length < 2 || ((const char*)indexedJSONData.bytes)[0] != '{')
                return nil;
            NSDictionary* dict = [NSJSONSerialization JSONObjectWithData: indexedJSONData
                                                                 options: 0 error: NULL];
            if (dictToAdd.count == 0)
                return (id)dict;
            NSMutableDictionary* mdict = [dict mutableCopy];
            [mdict addEntriesFromDictionary: dictToAdd];
            return (id)mdict;
        }

        _data = [indexedJSONData copy];
        _header = (const DictHeader*)_data.bytes;
        UInt16 count = EndianU16_BtoN(_header->count);
        _json = (const uint8_t*)&_header->entry[count];
        _addToCache = cacheValues;
        if (dictToAdd.count > 0) {
            _hasAddedValues = YES;
            _cache = [dictToAdd mutableCopy];
        } else if (cacheValues) {
            _cache = [[NSMutableDictionary alloc] init];
        }
    }
    return self;
}


@synthesize JSONData=_data;


- (const uint8_t*) _findValueFor:(id)key end: (const uint8_t**)endOfValue {
    NSParameterAssert(key != nil);
    uint16_t hash = [CBIndexedJSONEncoder indexHash: key];
    const DictEntry* entry = _header->entry;
    for (NSUInteger i = EndianU16_BtoN(_header->count); i > 0; i--, entry++) {
        if (EndianU16_BtoN(entry->hash) == hash) {
            // Hash code matches entry; now compare the key strings:
            const uint8_t* jsonKey = _json + EndianU16_BtoN(entry->offset);
            const uint8_t* jsonValue = matchString(jsonKey, key);
            if (jsonValue) {
                // Keys match! Find the byte range of the value:
                jsonValue++; // skip the ':'
                if (i > 1)
                    *endOfValue = _json + EndianU16_BtoN((entry+1)->offset) - 1;
                else
                    *endOfValue = _data.bytes + _data.length - 1;
                return jsonValue;
            }
        }
    }
    return NULL;
}


- (BOOL)containsValueForKey:(NSString *)key {
    if (_cache[key] != nil )
        return YES;
    const uint8_t* end;
    return [self _findValueFor: key end: &end] != NULL;
}


- (NSUInteger) count {
    if (_count == 0) {
        _count = EndianU16_BtoN(_header->count);
        if (_hasAddedValues) {
            for (NSString* key in _cache) {
                const uint8_t* end;
                if ([self _findValueFor: key end: &end] == NULL)
                    _count++;
            }
        }
    }
    return _count;
}


- (id) objectForKey:(id)key {
    id value = _cache[key];
    if (value)
        return value;
    if (key && ![key isKindOfClass: [NSString class]])
        return nil;

    const uint8_t* endOfValue;
    const uint8_t* jsonValue = [self _findValueFor: key end: &endOfValue];
    if (!jsonValue)
        return nil;
    NSData* valueData = [[NSData alloc] initWithBytesNoCopy: (void*)jsonValue
                                                     length: endOfValue - jsonValue
                                               freeWhenDone: NO];
    if (!valueData)
        return nil;
    NSError* error;
    value = [NSJSONSerialization JSONObjectWithData: valueData
                                               options: NSJSONReadingAllowFragments
                                                 error: &error];
    if (!value)
        NSLog(@"WARNING: CBLIndexedJSONDict: Unparseable JSON value for key \"%@\"", key);
    else if (_addToCache)
        _cache[key] = value;
    return value;
}


// Compares a JSON string to an NSString. jsonKey points to the opening quote character.
// Returns a pointer to the byte past the closing quote character on match, or NULL on mismatch.
static const uint8_t* matchString(const uint8_t* jsonKey, NSString* keyStr) {
    __block const uint8_t* end = NULL;
    [CBJSONEncoder string: keyStr processBytes: ^(const char *keyUTF8, size_t utf8Len) {
        size_t keyUTF8Index = 0;
        const uint8_t* pos = jsonKey + 1; // skip opening quote
        while (*pos != '"') {
            //TODO: Interpret "\" character!!
            if (keyUTF8Index >= utf8Len || *pos != keyUTF8[keyUTF8Index])
                return; // doesn't match
            keyUTF8Index++;
            pos++;
        }
        if (keyUTF8Index == utf8Len)
            end = pos + 1; // match!
    }];
    return end;
}


- (NSArray*) allKeys {
    NSMutableArray* keys = [NSMutableArray arrayWithCapacity: _header->count];
    const DictEntry* entry = _header->entry;
    for (NSUInteger i = EndianU16_BtoN(_header->count); i > 0; i--, entry++) {
        const uint8_t* jsonKey = _json + EndianU16_BtoN(entry->offset);
        NSString* key = extractString(jsonKey);
        if (key)
            [keys addObject: key];
    }

    if (_hasAddedValues) {
        for (NSString* key in _cache) {
            const uint8_t* end;
            if ([self _findValueFor: key end: &end] == NULL)
                [keys addObject: key];
        }
    }
    return keys;
}


- (NSEnumerator *)keyEnumerator {
    return self.allKeys.objectEnumerator;
}


// Given a pointer to a JSON string, return it as an NSString
static NSString* extractString(const uint8_t* jsonKey) {
    const uint8_t* start = jsonKey + 1; // skip opening quote
    const uint8_t* end = start;
    while (*end != '"' || end[-1] == '\\') {
        end++;
    }
    // TODO: Decode '\' escapes!
    return [[NSString alloc] initWithBytes: start length: end-start encoding: NSUTF8StringEncoding];
}


@end
