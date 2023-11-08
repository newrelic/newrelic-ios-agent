//
//  NRMANetworkMonitor.m
//  Agent
//
//  Created by Mike Bruin on 10/3/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Network/Network.h>

#import "NRMANetworkMonitor.h"

@interface NRMANetworkMonitor()

@property (nonatomic, strong) nw_path_monitor_t monitor;
@property (nonatomic, strong) dispatch_queue_t monitorQueue;
@property (nonatomic, strong) NSString* connectionType;

@end

@implementation NRMANetworkMonitor

- (instancetype)init {
    self = [super init];
    if (self) {
        self.connectionType = @"unknown";
        [self startNetworkMonitoring];
    }
    return self;
}

- (void) startNetworkMonitoring {
    self.monitorQueue = dispatch_queue_create("com.newrelic.network.monitor", dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, DISPATCH_QUEUE_PRIORITY_DEFAULT));
    self.monitor = nw_path_monitor_create();
    nw_path_monitor_set_queue(self.monitor, self.monitorQueue);
    
    nw_path_monitor_set_update_handler(self.monitor, ^(nw_path_t _Nonnull path) {
        @synchronized(self.connectionType){
            if(nw_path_get_status(path) == nw_path_status_satisfied) {
                if(nw_path_uses_interface_type(path, nw_interface_type_cellular)) {
                    self.connectionType = @"cellular";
                } else if (nw_path_uses_interface_type(path, nw_interface_type_wifi)) {
                    self.connectionType = @"wifi";
                } else if (nw_path_uses_interface_type(path, nw_interface_type_wired)) {
                    self.connectionType = @"ethernet";
                } else {
                    self.connectionType = @"unknown";
                }
            }
        }
    });
    nw_path_monitor_start(self.monitor);
}

- (void) stopNetworkMonitoring {
    nw_path_monitor_cancel(self.monitor);
}

- (NSString*) getConnectionType {
    @synchronized(self.connectionType){
        return _connectionType;
    }
}

@end
