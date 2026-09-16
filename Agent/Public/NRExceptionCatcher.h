// NRExceptionCatcher.h
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

@interface NRExceptionCatcher : NSObject
+ (BOOL)tryBlock:(void (NS_NOESCAPE ^)(void))tryBlock
      catchBlock:(void (^)(NSException *exception))catchBlock;
@end

NS_ASSUME_NONNULL_END
