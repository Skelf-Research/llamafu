#import <Flutter/Flutter.h>
#import <UIKit/UIKit.h>

@interface LlamafuPlugin : NSObject<FlutterPlugin>
@end

@implementation LlamafuPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"llamafu"
            binaryMessenger:[registrar messenger]];
  [channel setMethodCallHandler:^(FlutterMethodCall* call, FlutterResult result) {
    if ([@"getPlatformVersion" isEqualToString:call.method]) {
      result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
    } else if ([@"getDeviceInfo" isEqualToString:call.method]) {
      NSMutableDictionary* deviceInfo = [[NSMutableDictionary alloc] init];
      [deviceInfo setObject:[[UIDevice currentDevice] systemVersion] forKey:@"systemVersion"];
      [deviceInfo setObject:[[UIDevice currentDevice] model] forKey:@"model"];
      [deviceInfo setObject:[[UIDevice currentDevice] name] forKey:@"name"];

      // Add architecture information
      #if TARGET_OS_SIMULATOR
        [deviceInfo setObject:@"simulator" forKey:@"architecture"];
      #elif defined(__arm64__)
        [deviceInfo setObject:@"arm64" forKey:@"architecture"];
      #elif defined(__arm__)
        [deviceInfo setObject:@"arm" forKey:@"architecture"];
      #else
        [deviceInfo setObject:@"unknown" forKey:@"architecture"];
      #endif

      result(deviceInfo);
    } else if ([@"checkLibrarySupport" isEqualToString:call.method]) {
      // Check if the native library is available
      // In a real implementation, this would check for the llamafu library
      NSDictionary* supportInfo = @{
        @"nativeLibraryAvailable": @YES,
        @"multimodalSupport": @YES,
        @"loraSupport": @YES,
        @"grammarSupport": @YES
      };
      result(supportInfo);
    } else {
      result(FlutterMethodNotImplemented);
    }
  }];
}

@end