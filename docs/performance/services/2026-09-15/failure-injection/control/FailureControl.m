#import <AppKit/AppKit.h>
@interface FailureControl : NSObject
@end
@implementation FailureControl
- (void)fail:(NSPasteboard *)board userData:(NSString *)userData error:(NSString **)error {
    fprintf(stderr, "CONTROL_HANDLER_ENTERED errorPointerPresent=%d\n", error != NULL);
    if (error) *error = @"Intentional OpenCCman diagnostic error";
}
@end
int main(void) {
    @autoreleasepool {
        FailureControl *provider = [FailureControl new];
        NSRegisterServicesProvider(provider, @"OpenCCmanFailureControlEAB5003");
        fprintf(stderr, "CONTROL_READY\n");
        [[NSRunLoop currentRunLoop] run];
    }
    return 0;
}
