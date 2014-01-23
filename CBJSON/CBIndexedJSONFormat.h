//
//  CBIndexedJSONFormat.h
//  CBJSON
//
//  Created by Jens Alfke on 12/30/13.
//  Copyright (c) 2013 Couchbase. All rights reserved.
//

#import <stdint.h>

/*  Data format:
    uint16      magic number
    uint16      count
    {
        uint16 hash
        uint16 offset
    }
    JSON data starts here
*/

#define kDictMagicNumber 0xD1C7

typedef struct {
    uint16_t hash, offset;
} DictEntry;

typedef struct {
    uint16_t magic;
    uint16_t count;
    DictEntry entry[0];
} DictHeader;
