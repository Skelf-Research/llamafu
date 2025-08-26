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
    } else {
      result(FlutterMethodNotImplemented);
    }
  }];
}

@end