#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ObjCExceptionCatcher : NSObject
+ (nullable NSException *)tryBlock:(void (^)(void))block NS_SWIFT_NAME(try(_:));
@end

NS_ASSUME_NONNULL_END
