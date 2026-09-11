// NRExceptionCatcher.m
#import "NRExceptionCatcher.h"

@implementation NRExceptionCatcher

+ (BOOL)tryBlock:(void (^)(void))tryBlock
      catchBlock:(void (^)(NSException *exception))catchBlock {
    @try {
        tryBlock();
        return YES;
    } @catch (NSException *exception) {
        if (catchBlock) {
            catchBlock(exception);
        }
        return NO;
    }
}

@end
