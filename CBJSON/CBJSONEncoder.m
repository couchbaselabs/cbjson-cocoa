//
//  CBJSONEncoder.m
//  CBJSON
//
//  Created by Jens Alfke on 12/27/13.
//  Copyright (c) 2013 Couchbase. All rights reserved.
//

#import "CBJSONEncoder.h"
#include "yajl/yajl_gen.h"


static void appendData(void *ctx, const char* bytes, size_t length) {
    NSMutableData* encoded = (__bridge NSMutableData*)ctx;
    [encoded appendBytes: bytes length: length];
}


@implementation CBJSONEncoder
{
    NSMutableData* _encoded;
    yajl_gen _gen;
    yajl_gen_status _status;
}


+ (NSData*) encode: (id)object error: (NSError**)outError {
    CBJSONEncoder* encoder = [[self alloc] init];
    if ([encoder encode: object])
        return encoder.encodedData;
    else if (outError)
        *outError = encoder.error;
    return nil;
}


- (instancetype) init {
    self = [super init];
    if (self) {
        _encoded = [NSMutableData dataWithCapacity: 1024];
        _gen = yajl_gen_alloc(NULL);
        if (!_gen)
            return nil;
        yajl_gen_config(_gen, yajl_gen_print_callback, &appendData, (__bridge void*)_encoded);
    }
    return self;
}


- (void) dealloc {
    if (_gen)
        yajl_gen_free(_gen);
}


- (BOOL) encode: (id)object {
    return [self encodeNestedObject: object];
}


@synthesize encodedData=_encoded;

- (NSMutableData*) output {
    return _encoded;
}


- (BOOL) encodeNestedObject: (id)object {
    if ([object isKindOfClass: [NSString class]]) {
        return [self encodeString: object];
    } else if ([object isKindOfClass: [NSNumber class]]) {
        return [self encodeNumber: object];
    } else if ([object isKindOfClass: [NSNull class]]) {
        return [self encodeNull];
    } else if ([object isKindOfClass: [NSDictionary class]]) {
        return [self encodeDictionary: object];
    } else if ([object isKindOfClass: [NSArray class]]) {
        return [self encodeArray: object];
    } else {
        return NO;
    }
}


- (BOOL) encodeString: (NSString*)str {
    __block yajl_gen_status status = yajl_gen_invalid_string;
    [[self class] string: str processBytes: ^(const char *chars, size_t len) {
        status = yajl_gen_string(_gen, (const unsigned char*)chars, len);
    }];
    return [self checkStatus: status];
}


- (BOOL) encodeNumber: (NSNumber*)number {
    const char* encoding = number.objCType;
    yajl_gen_status status;
    if (encoding[0] == 'c')
        status = yajl_gen_bool(_gen, number.boolValue);
    else
        status = yajl_gen_double(_gen, number.doubleValue);
    return [self checkStatus: status];
}


- (BOOL) encodeNull {
    return [self checkStatus: yajl_gen_null(_gen)];
}


- (BOOL) encodeArray: (NSArray*)array {
    yajl_gen_array_open(_gen);
    for (id item in array)
        if (![self encodeNestedObject: item])
            return NO;
    return [self checkStatus: yajl_gen_array_close(_gen)];
}

- (BOOL) encodeKey: (id)key value: (id)value {
    return [self encodeNestedObject: key] && [self encodeNestedObject: value];
}

- (BOOL) encodeDictionary: (NSDictionary*)dict {
    if (![self checkStatus: yajl_gen_map_open(_gen)])
        return NO;
    for (NSString* key in dict)
        if (![self encodeKey: key value: dict[key]])
            return NO;
    return [self checkStatus: yajl_gen_map_close(_gen)];
}


- (BOOL) checkStatus: (yajl_gen_status)status {
    if (status == yajl_gen_status_ok)
        return YES;
    _status = status;
    return NO;
}


- (NSError*) error {
    if (_status == yajl_gen_status_ok)
        return nil;
    return [NSError errorWithDomain: @"YAJL" code: _status userInfo: nil];
}


+ (BOOL) string: (NSString*)str processBytes: (void (^)(const char*, size_t))block {
    // First attempt: Get a C string directly from the CFString if it's in the right format:
    const char* cstr = CFStringGetCStringPtr((CFStringRef)str, kCFStringEncodingUTF8);
    if (cstr) {
        block(cstr, strlen(cstr));
        return YES;
    }

    NSUInteger byteCount;
    if (str.length < 256) {
        // First try to copy the UTF-8 into a smallish stack-based buffer:
        char stackBuf[256];
        NSRange remaining;
        BOOL ok = [str getBytes: stackBuf maxLength: sizeof(stackBuf) usedLength: &byteCount
                       encoding: NSUTF8StringEncoding options: 0
                          range: NSMakeRange(0, str.length) remainingRange: &remaining];
        if (ok && remaining.length == 0) {
            block(stackBuf, byteCount);
            return YES;
        }
    }

    // Otherwise malloc a buffer to copy the UTF-8 into:
    NSUInteger maxByteCount = [str maximumLengthOfBytesUsingEncoding: NSUTF8StringEncoding];
    char* buf = malloc(maxByteCount);
    if (!buf)
        return NO;
    BOOL ok = [str getBytes: buf maxLength: maxByteCount usedLength: &byteCount
                   encoding: NSUTF8StringEncoding options: 0
                      range: NSMakeRange(0, str.length) remainingRange: NULL];
    if (ok)
        block(buf, byteCount);
    free(buf);
    return ok;
}


@end
