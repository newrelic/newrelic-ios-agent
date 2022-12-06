//
//  NRMAHarvesterConnection+GZip.m
//  NewRelicAgent
//
//  Created by Chris Dillard on 4/18/22.
//  Copyright (c) 2022 New Relic. All rights reserved.
//

#import "NRMAHarvesterConnection+GZip.h"
#import <zlib.h>

@implementation NRMAHarvesterConnection (GZip)

// This gzip encoding code was moved from NRMAHarvesterConnection where it is used during posts with length > 512.
+ (NSData*) gzipData:(NSData*)messageData {

    z_stream zStream;

    zStream.zalloc = Z_NULL;
    zStream.zfree = Z_NULL;
    zStream.opaque = Z_NULL;
    zStream.next_in = (Bytef *)messageData.bytes;
    zStream.avail_in = (uint)messageData.length;
    zStream.total_out = 0;

    if (deflateInit(&zStream, Z_DEFAULT_COMPRESSION) == Z_OK) {
        NSUInteger compressionChunkSize = 16384; // 16Kb
        NSMutableData *compressedData = [NSMutableData dataWithLength:compressionChunkSize];

        do {
            if (zStream.total_out >= [compressedData length]) {
                [compressedData increaseLengthBy:compressionChunkSize];
            }

            zStream.next_out = [compressedData mutableBytes] + zStream.total_out;
            zStream.avail_out = (unsigned int)[compressedData length] - (unsigned int)zStream.total_out;

            deflate(&zStream, Z_FINISH);

        } while (zStream.avail_out == 0);

        deflateEnd(&zStream);
        [compressedData setLength:zStream.total_out];

        messageData = [NSData dataWithData:compressedData];

    }
    return messageData;
}

@end
