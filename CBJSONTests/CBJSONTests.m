//
//  CBJSONTests.m
//  CBJSONTests
//
//  Created by Jens Alfke on 12/27/13.
//  Copyright (c) 2013 Couchbase. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "CBIndexedJSONEncoder.h"
#import "CBIndexedJSONDict.h"
#import "CBIndexedJSONFormat.h"


@interface CBJSONTests : XCTestCase
@end


@implementation CBJSONTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (NSDictionary*) sampleDict {
    return @{@"num": @(1234),
             @"string": @"String value!",
             @"": [NSNull null]};
}

// Returns some sample encoded data
- (NSData*) sampleEncodedData {
    CBIndexedJSONEncoder* encoder = [[CBIndexedJSONEncoder alloc] init];
    XCTAssertTrue([encoder encode: self.sampleDict], @"encode failed");
    return encoder.encodedData;
}

- (void) testFormat {
    XCTAssertEqual(sizeof(DictEntry), (size_t)4);
    XCTAssertEqual(sizeof(DictHeader), (size_t)4);
    XCTAssertEqual(offsetof(DictHeader,entry[2].hash), (size_t)12);
}

- (void)testIndexedEncoder {
    NSDictionary* dict = self.sampleDict;
    NSData* encoded = self.sampleEncodedData;
    NSLog(@"Encoded: %@", encoded);

    const DictHeader* h = encoded.bytes;
    XCTAssertEqual(EndianU16_BtoN(h->count), (UInt16)dict.count);
    XCTAssertEqual(EndianU16_BtoN(h->magic), (UInt16)kDictMagicNumber);
    XCTAssertEqual(EndianU16_BtoN(h->entry[0].hash), (UInt16)32896);
    XCTAssertEqual(EndianU16_BtoN(h->entry[0].offset), (UInt16)1);
    XCTAssertEqual(EndianU16_BtoN(h->entry[1].hash), (UInt16)31403);
    XCTAssertEqual(EndianU16_BtoN(h->entry[1].offset), (UInt16)14);
    XCTAssertEqual(EndianU16_BtoN(h->entry[2].hash), (UInt16)0);
    XCTAssertEqual(EndianU16_BtoN(h->entry[2].offset), (UInt16)39);

    // Make sure each entry offset points to a '"' character:
    const char* json = (const char*)&h->entry[dict.count];
    for (int i=0; i<dict.count; i++) {
        UInt16 offset = EndianU16_BtoN(h->entry[i].offset);
        XCTAssertEqual(json[offset], (char)'"', @"Entry #%d, offset %u", i,offset);
    }

    XCTAssertTrue([CBIndexedJSONEncoder isValidIndexedJSON: encoded]);
}

- (void)testIndexedDict {
    NSDictionary* dict = self.sampleDict;
    NSData* encoded = self.sampleEncodedData;

    CBIndexedJSONDict* parsed = [[CBIndexedJSONDict alloc] initWithData: encoded
                                                           addingValues: nil
                                                            cacheValues: NO];
    XCTAssertNotNil(parsed);
    XCTAssertEqual(parsed.count, (size_t)3);
    XCTAssertEqualObjects(parsed[@"num"], @1234);
    XCTAssertEqualObjects(parsed[@"Num"], nil);
    XCTAssertEqualObjects(parsed[@"string"], dict[@"string"]);
    XCTAssertEqualObjects(parsed[@""], dict[@""]);

    XCTAssertTrue([parsed containsValueForKey: @"num"]);
    XCTAssertTrue([parsed containsValueForKey: @""]);
    XCTAssertFalse([parsed containsValueForKey: @"*"]);

    // Test key enumerator:
    NSEnumerator* e = parsed.keyEnumerator;
    XCTAssertNotNil(e);
    XCTAssertEqualObjects(e.nextObject, @"num");
    XCTAssertEqualObjects(e.nextObject, @"string");
    XCTAssertEqualObjects(e.nextObject, @"");

    // Test fast-enumeration:
    NSMutableSet* keys = [NSMutableSet set];
    for (NSString* key in parsed) {
        [keys addObject: key];
    }
    XCTAssertEqualObjects(keys, [NSSet setWithArray: dict.allKeys]);

    NSDictionary* copied = [parsed copy];
    XCTAssertEqualObjects(copied, parsed);
    NSLog(@"Original = %@ %@", parsed.class, parsed);
    NSLog(@"Copy = %@ %@", copied.class, copied);
}

- (void) testAddingValues {
    NSDictionary* dict = self.sampleDict;
    NSData* encoded = self.sampleEncodedData;

    NSDictionary* added = @{@"_id": @"foo", @"num": @4321};
    CBIndexedJSONDict* parsed = [[CBIndexedJSONDict alloc] initWithData: encoded
                                                           addingValues: added
                                                            cacheValues: NO];
    XCTAssertEqual(parsed.count, (size_t)4);
    XCTAssertEqualObjects(parsed[@"num"], @4321); // overridden by added dict
    XCTAssertEqualObjects(parsed[@"Num"], nil);
    XCTAssertEqualObjects(parsed[@"string"], dict[@"string"]);
    XCTAssertEqualObjects(parsed[@""], dict[@""]);
    XCTAssertEqualObjects(parsed[@"_id"], @"foo");

    XCTAssertTrue([parsed containsValueForKey: @"_id"]);
    XCTAssertTrue([parsed containsValueForKey: @"num"]);

    XCTAssertEqualObjects(([NSSet setWithArray: parsed.allKeys]),
                          ([NSSet setWithObjects: @"_id", @"num", @"string", @"", nil]));
}

static NSTimeInterval benchmark(void (^block)()) {
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    @autoreleasepool {
        block();
    }
    CFAbsoluteTime elapsed = CFAbsoluteTimeGetCurrent() - start;
    return elapsed;
}

- (void) testBeers {
    NSString* dir = @"/opt/couchbase/samples/beer-sample/docs"; //TEMP
    NSMutableArray* jsonDocs = [NSMutableArray array];
    NSMutableArray* indexedJsonDocs = [NSMutableArray array];
    for (NSString* filename in [[NSFileManager defaultManager] enumeratorAtPath: dir]) {
        NSString* path = [dir stringByAppendingPathComponent: filename];
        NSData* jsonData = [NSData dataWithContentsOfFile: path];
        [jsonDocs addObject: jsonData];

        NSDictionary* body = [NSJSONSerialization JSONObjectWithData: jsonData
                                                             options: 0 error: NULL];
        NSData* indexedData = [CBIndexedJSONEncoder encode: body error: NULL];
        [indexedJsonDocs addObject: indexedData];
    }
    NSLog(@"Read %u beer docs", (unsigned)indexedJsonDocs.count);

    __block UInt64 totalZip = 0;
    NSTimeInterval jsonTime = benchmark(^{
        for (NSData* jsonData in jsonDocs) {
            NSDictionary* body = [NSJSONSerialization JSONObjectWithData: jsonData
                                                                 options: 0 error: NULL];
            NSString* zip = body[@"code"];
            totalZip += [zip integerValue];
        }
    });
    NSLog(@"%1.10f sec for NSJSONSerialization", jsonTime);

    __block UInt64 indexedTotalZip = 0;
    NSTimeInterval indexedTime = benchmark(^{
        for (NSData* jsonData in indexedJsonDocs) {
            NSDictionary* body = [[CBIndexedJSONDict alloc] initWithData: jsonData
                                                            addingValues: nil cacheValues: NO];
            NSString* zip = body[@"code"];
            indexedTotalZip += [zip integerValue];
        }
    });
    NSLog(@"%1.10f sec for indexed JSON", indexedTime);
    XCTAssertEqual(indexedTotalZip, totalZip);
    NSLog(@"Speedup = %.2fx", jsonTime/indexedTime);
}

@end
