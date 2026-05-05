#import "ObjCExceptionCatcher.h"

@implementation ObjCExceptionCatcher
+ (NSException *)tryBlock:(void (^)(void))block {
    @try {
        block();
        return nil;
    } @catch (NSException *exception) {
        return exception;
    }
}
@end
