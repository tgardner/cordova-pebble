
#import <Cordova/CDVPlugin.h>
#import <PebbleKit/PebbleKit.h>

@interface Pebble : CDVPlugin <PBPebbleCentralDelegate>
{
    NSMutableDictionary* watches;
}

@property (nonatomic, strong) NSString* connectCallbackId;
@property (nonatomic, strong) NSString* messageCallbackId;

@end
