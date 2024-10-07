//
//  NRMASessionReplayFrame.m
//  Agent_iOS
//
//  Created by Steve Malsam on 9/20/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

/*
{
    "type": 0,
    "childNodes": [
        {
            "type": 2,
            "tagName": "html",
            "attributes": {},
            "childNodes": [
                {
                    "type": 2,
                    "tagName": "head",
                    "attributes": {},
                    "childNodes": [
                        {
                            "type": 2,
                            "tagName": "style",
                            "attributes": {},
                            "childNodes": [
                                {
                                    "type": 3,
                                    "textContent": "#we-add-style-rules-here {background-color: red;}",
                                    "isStyle": true,
                                    "id": 5
                                }
                            ],
                            "id": 4
                        }
                    ],
                    "id": 3
                },
                {
                    "type": 2,
                    "tagName": "body",
                    "attributes": {},
                    "childNodes": [
                        {
                            "type": 2,
                            "tagName": "p",
                            "attributes": {},
                            "childNodes": [
                                {
                                    "type": 3,
                                    "textContent": "the p element is where our element nodes go in the dom tree",
                                    "id": 8
                                }
                            ],
                            "id": 7
                        }
                    ],
                    "id": 6
                }
            ],
            "id": 2
        }
    ],
    "compatMode": "BackCompat",
    "id": 1
}
 */

#import "NRMASessionReplayFrame.h"

#import "NRMAIdGenerator.h"

@implementation NRMASessionReplayFrame {
    NSArray<NRMAUIViewDetails *>* _nodes;
}

- (instancetype)initWithTimestamp:(NSDate *)date andNodes:(NSArray<id> *)nodes {
    self = [super init];
    if (self) {
        _timestamp = date;
        _nodes = nodes;
    }
    
    return self;
}

@end
