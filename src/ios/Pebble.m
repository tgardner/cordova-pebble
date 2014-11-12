
#import "Pebble.h"

@implementation Pebble

@synthesize connectCallbackId;
@synthesize messageCallbackId;

-(void)onConnect:(CDVInvokedUrlCommand *)command
{
    self.connectCallbackId = command.callbackId;
    
    NSString *uuidString = [command.arguments objectAtIndex:0];
    
    NSLog(@"PGPebble setAppUUID() with %@", uuidString);
    
    uuid_t uuidBytes;
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:uuidString];
    [uuid getUUIDBytes:uuidBytes];
    NSLog(@"%@", uuid);
    
    [[PBPebbleCentral defaultCentral] setAppUUID:[NSData dataWithBytes:uuidBytes length:16]];
    
    NSArray *connected = [[PBPebbleCentral defaultCentral] connectedWatches];
    if ([connected count] > 0) {
        NSLog(@"Pebble watch found at startup");
        
        for (PBWatch* watch in connected) {
            [self watchConnected:watch];
        }
    }
}

-(void)onAppMessageReceived:(CDVInvokedUrlCommand *)command
{
    self.messageCallbackId = command.callbackId;
}

-(void)launchApp:(CDVInvokedUrlCommand *)command
{
    if (![self checkWatchConnected]) return;
    
    NSLog(@"Pebble launchApp()");
    
    for (NSString* key in watches) {
        PBWatch* watch = [watches objectForKey:key];
        
        [watch appMessagesLaunch:^(PBWatch *watch, NSError *error) {
            [self notifyBooleanCallback:command.callbackId withResult:!error];
        }];
    }
    
}

-(void)killApp:(CDVInvokedUrlCommand *)command
{
    if (![self checkWatchConnected]) return;
    
    NSLog(@"Pebble killApp()");
    
    for (NSString* key in watches) {
        PBWatch* watch = [watches objectForKey:key];
        
        [watch appMessagesKill:^(PBWatch *watch, NSError *error) {
            [self notifyBooleanCallback:command.callbackId withResult:!error];
        }];
    }
}

-(void)sendAppMessage:(CDVInvokedUrlCommand *)command
{
    if (![self checkWatchConnected]) return;
    
    NSLog(@"Pebble sendMessage()");
    
    NSString *jsonStr = [command.arguments objectAtIndex:0];
    jsonStr = [jsonStr stringByReplacingOccurrencesOfString:@"\\\"" withString:@"\""];
    NSData *jsonData = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    
    NSMutableDictionary* update = [NSMutableDictionary dictionaryWithCapacity:[result count]];
    NSNumberFormatter * f = [[NSNumberFormatter alloc] init];
    [f setNumberStyle:NSNumberFormatterDecimalStyle];
    
    for (NSString* key in result) {
        NSNumber * keyNum = [f numberFromString:key];
        [update setObject:[result objectForKey:key] forKey:keyNum];
    }
    
    NSLog(@"Pebble SDK will send update %@", update);
    
    for (NSString* key in watches) {
        PBWatch* watch = [watches objectForKey:key];
        
        [watch appMessagesPushUpdate:update onSent:^(PBWatch *watch, NSDictionary *update, NSError *error) {
            if(!error) {
                NSLog(@"Pebble: Successfully sent message.");
            } else {
                NSLog(@"Pebble: Error sending message: %@", error);
            }
            
            [self notifyBooleanCallback:command.callbackId withResult:!error];
        }];
    }
}


#pragma mark utils

- (void)pluginInitialize
{
    
    [[PBPebbleCentral defaultCentral] setDelegate:self];
    watches = [[NSMutableDictionary alloc] init];
    
}

- (void) listenToWatch:(PBWatch*) watch
{
    [watch appMessagesAddReceiveUpdateHandler:^BOOL(PBWatch *watch, NSDictionary *update) {
        NSLog(@"Pebble: received message: %@", update);
        
        NSMutableDictionary* returnInfo = [[NSMutableDictionary alloc] init];
        [returnInfo setObject:[watch name] forKey:@"watch"];
        
        for (NSNumber *key in update) {
            [returnInfo setObject:[update objectForKey:key] forKey:[key stringValue]];
        }
        
        [self notifyKeepCallback:self.messageCallbackId withStatus:CDVCommandStatus_OK andWithData:returnInfo];
        
        return YES;
    }];
}

- (void)notifyKeepCallback:(NSString*) callbackId
                withStatus:(CDVCommandStatus) status
               andWithData:(NSMutableDictionary*) data
{
    CDVPluginResult* result = [CDVPluginResult resultWithStatus: status messageAsDictionary:data];
    [result setKeepCallbackAsBool:YES];
    
    [self.commandDelegate sendPluginResult:result callbackId:callbackId];
}

- (void)notifyBooleanCallback:(NSString*) callbackId
                   withResult:(BOOL)success
{
    NSMutableDictionary* data = [NSMutableDictionary dictionaryWithCapacity:1];
    CDVPluginResult* result = NULL;
    
    if(success) {
        [data setObject:@"true" forKey:@"success"];
        
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:data];
    } else {
        NSLog(@"error launching Pebble app");
        
        [data setObject:@"false" forKey:@"success"];
        
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:data];
    }
    
    [self.commandDelegate sendPluginResult:result callbackId:callbackId];
}

-(BOOL)checkWatchConnected
{
    if ([watches count] == 0) {
        NSLog(@"Pebble: No watches connected.");
        
        return FALSE;
    }
    else {
        return TRUE;
    }
}

-(void)watchConnected:(PBWatch*) watch
{
    [watches setObject:watch forKey:[watch name]];
    
    NSLog(@"watchConnected");
    
    [self listenToWatch:watch];
    
    NSMutableDictionary* returnInfo = [NSMutableDictionary dictionaryWithCapacity:1];
    [returnInfo setObject:[watch name] forKey:@"name"];
    
    [self notifyKeepCallback:self.connectCallbackId withStatus:CDVCommandStatus_OK andWithData:returnInfo];
}

-(void)watchDisconnected:(PBWatch*) watch
{
    [watches removeObjectForKey:[watch name]];
    
    NSMutableDictionary* returnInfo = [NSMutableDictionary dictionaryWithCapacity:1];
    [returnInfo setObject:[watch name] forKey:@"name"];
    
    [self notifyKeepCallback:self.connectCallbackId withStatus:CDVCommandStatus_ERROR andWithData:returnInfo];
}

#pragma mark delegate methods

- (void)pebbleCentral:(PBPebbleCentral*)central
      watchDidConnect:(PBWatch*)watch
                isNew:(BOOL)isNew
{
    NSLog(@"Pebble connected: %@", [watch name]);
    
    [self watchConnected:watch];
}


- (void)pebbleCentral:(PBPebbleCentral*)central
   watchDidDisconnect:(PBWatch*)watch
{
    NSLog(@"Pebble disconnected: %@", [watch name]);
    
    [self watchDisconnected:watch];
}

@end
