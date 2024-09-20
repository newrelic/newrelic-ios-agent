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
    NSMutableDictionary* rootNode;
    NSMutableDictionary* styleNode;
    NSMutableDictionary* bodyNode;
}

- (instancetype)init {
    self = [super init];
    if(self) {
        [self generateInitialBoilerplate];
    }
    
    return self;
}

-(void)addStyleNodes:(NSString *)styleNodes{
    NSDictionary *textStyleNode = @{@"type": @(3),
                                    @"isStyle": @(YES),
                                    @"id":@([NRMAIdGenerator generateID]),
                                    @"textContent":styleNodes};
    
    [styleNode[@"childNodes"] addObject:textStyleNode];
}

-(void)addBodyNodes:(NSDictionary *)bodyNodes{
    [bodyNode[@"childNodes"] addObject:bodyNodes];
}

-(NSDictionary *)getFrame {
    return rootNode;
}

- (NSMutableDictionary *)generateInitialBoilerplate {
    rootNode = [NSMutableDictionary new];
    rootNode[@"type"] = @(2);
    
    NSMutableDictionary *node = [NSMutableDictionary new];
    node[@"type"] = @(0);
    node[@"id"] = @([NRMAIdGenerator generateID]);
    node[@"childNodes"] = [NSMutableArray new];
    
    NSMutableDictionary *initialOffset = [NSMutableDictionary new];
    initialOffset[@"left"] = @(0);
    initialOffset[@"top"] = @(0);
    
    NSMutableDictionary *htmlNode = [self generateHTMLNode];
    NSMutableDictionary *headNode = [self generateHeadNode];
    styleNode = [self generateStyleNode];
    bodyNode = [self generateBodyNode];
    
    [((NSMutableArray *)headNode[@"childNodes"]) addObject:styleNode];
    [((NSMutableArray *)htmlNode[@"childNodes"]) addObject:headNode];
    [((NSMutableArray *)htmlNode[@"childNodes"]) addObject:bodyNode];
    
    [node[@"childNodes"] addObject:htmlNode];
    
    NSMutableDictionary *data = [NSMutableDictionary new];
    data[@"node"] = node;
    data[@"initialOffset"] = initialOffset;
    rootNode[@"data"] = data;
    rootNode[@"timestamp"] = @([[NSDate now] timeIntervalSince1970]);
    return rootNode;
}

- (NSMutableDictionary *)generateHTMLNode {
    NSMutableDictionary *html = [[NSMutableDictionary alloc] init];
    html[@"type"] = @(2);
    html[@"tagName"] = @"html";
    html[@"attributes"] = @{};
    html[@"id"] = @([NRMAIdGenerator generateID]);
    html[@"childNodes"] = [NSMutableArray new];
    return html;
}

- (NSMutableDictionary *)generateHeadNode {
    NSMutableDictionary *head = [[NSMutableDictionary alloc] init];
    head[@"type"] = @(2);
    head[@"tagName"] = @"head";
    head[@"attributes"] = @{};
    head[@"id"] = @([NRMAIdGenerator generateID]);
    head[@"childNodes"] = [NSMutableArray new];
    return head;
}

- (NSMutableDictionary *)generateStyleNode {
    NSMutableDictionary *styles = [[NSMutableDictionary alloc] init];
    styles[@"type"] = @(2);
    styles[@"tagName"] = @"style";
    styles[@"attributes"] = @{};
    styles[@"id"] = @([NRMAIdGenerator generateID]);
    styles[@"childNodes"] = [NSMutableArray new];
    
    return styles;
}

- (NSMutableDictionary *)generateBodyNode {
    NSMutableDictionary *body = [[NSMutableDictionary alloc] init];
    body[@"type"] = @(2);
    body[@"tagName"] = @"body";
    body[@"attributes"] = @{};
    body[@"id"] = @([NRMAIdGenerator generateID]);
    body[@"childNodes"] = [NSMutableArray new];
    return body;
}

@end
