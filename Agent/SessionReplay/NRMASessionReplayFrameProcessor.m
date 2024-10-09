//
//  NRMASessionReplayFrameProcessor.m
//  Agent_iOS
//
//  Created by Steve Malsam on 9/25/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRMASessionReplayFrameProcessor.h"
#import "NRMAIdGenerator.h"

@implementation NRMASessionReplayFrameProcessor {
    NSMutableDictionary* rootNode;
    NSMutableDictionary* styleNode;
    NSMutableDictionary* bodyNode;
}

- (NSDictionary *)process:(NRMASessionReplayFrame *)frame {
    [self generateInitialBoilerplateWithTimestamp:frame.timestamp];
    
    NSMutableString *css = [NSMutableString new];
    
    for(NRMAUIViewDetails* node in frame.nodes) {
        [css appendString:node.cssDescription];
        [bodyNode[@"childNodes"] addObject:node.jsonDescription];
    }

//    NSMutableDictionary *newDictionary = [NSMutableDictionary new];
//    [bodyNode[@"childNodes"] addObject:[self recursivelyGetChildNodesForNode:frame.nodes.firstObject andCSSString:css]];
    
    NSDictionary *textStyleNode = @{@"type": @(3),
                                    @"isStyle": @(YES),
                                    @"id":@([NRMAIdGenerator generateID]),
                                    @"textContent":css};
    
    [styleNode[@"childNodes"] addObject:textStyleNode];
    
    return rootNode;
}

- (NSMutableDictionary *)generateInitialBoilerplateWithTimestamp:(NSDate *)timestamp {
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
    rootNode[@"timestamp"] = @([timestamp timeIntervalSince1970] * 1000);
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

- (NSDictionary *)recursivelyGetChildNodesForNode:(NRMAUIViewDetails *)node andCSSString:(NSMutableString *)cssString {
    NSMutableDictionary *nodeDescription = node.jsonDescription;
    [cssString appendString:node.cssDescription];
    
    for(NRMAUIViewDetails * childNode in node.childViews) {
        [((NSMutableArray *)nodeDescription[@"childNodes"]) addObject:[self recursivelyGetChildNodesForNode:childNode andCSSString:cssString]];
    }
    
    return nodeDescription;
}

@end
