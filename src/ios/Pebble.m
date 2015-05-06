
#import "Pebble.h"

@implementation Pebble {
    NSMutableDictionary* watches;
    
    NSMutableArray* connectCallbacks;
    NSMutableArray* messageCallbacks;
}

- (void)pluginInitialize
{
    
    [[PBPebbleCentral defaultCentral] setDelegate:self];
    watches = [[NSMutableDictionary alloc] init];
    connectCallbacks = [[NSMutableArray alloc] init];
    messageCallbacks = [[NSMutableArray alloc] init];
    
}

-(void)setAppUUID:(CDVInvokedUrlCommand *)command
{
    NSString *uuidString = [command.arguments objectAtIndex:0];
    
    uuid_t uuidBytes;
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:uuidString];
    [uuid getUUIDBytes:uuidBytes];
    
    CDVPluginResult* result;
    @try {
        NSLog(@"PGPebble setAppUUID() with %@", uuidString);
        [[PBPebbleCentral defaultCentral] setAppUUID:[NSData dataWithBytes:uuidBytes length:16]];
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    }
    @catch (NSException *exception) {
        NSDictionary *data = [[NSDictionary alloc] initWithObjectsAndKeys:exception.reason,@"reason", nil];
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary: data];
    }
    @finally {
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }
}

-(void)onConnect:(CDVInvokedUrlCommand *)command
{
    [connectCallbacks addObject: command.callbackId];
    
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
    [messageCallbacks addObject: command.callbackId];
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
                [self notifyBooleanCallback:command.callbackId withResult:true];
            } else {
                NSLog(@"Pebble: Error sending message: %@", error);
                [self notifyErrorCallback:command.callbackId withReason:error.description];
            }
        }];
    }
}


#pragma mark utils

- (void) listenToWatch:(PBWatch*) watch
{
    [watch appMessagesAddReceiveUpdateHandler:^BOOL(PBWatch *watch, NSDictionary *update) {
        NSLog(@"Pebble: received message: %@", update);
        
        NSMutableDictionary* returnInfo = [[NSMutableDictionary alloc]
                                           initWithObjectsAndKeys: [watch name], @"watch", nil];
        
        for (NSNumber *key in update) {
            [returnInfo setObject:[update objectForKey:key] forKey:[key stringValue]];
        }
        
        for(NSString* messageCallback in messageCallbacks) {
            [self notifyKeepCallback:messageCallback
                          withStatus:CDVCommandStatus_OK
                         andWithData:returnInfo];
        }
        
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

- (void) notifyErrorCallback:(NSString*) callbackId
                  withReason:(NSString*) reason
{
    
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:reason];
    [self.commandDelegate sendPluginResult:result callbackId:callbackId];
    
}

- (void)notifyBooleanCallback:(NSString*) callbackId
                   withResult:(BOOL)success
{
    CDVCommandStatus status = (success) ? CDVCommandStatus_OK : CDVCommandStatus_ERROR;
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:status];
    
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
    
    NSMutableDictionary* returnInfo = [[NSMutableDictionary alloc]
                                initWithObjectsAndKeys:[watch name],@"name", nil];
    
    for(NSString *connectCallback in connectCallbacks) {
        [self notifyKeepCallback: connectCallback
                      withStatus: CDVCommandStatus_OK
                     andWithData: returnInfo];
    }
}

-(void)watchDisconnected:(PBWatch*) watch
{
    [watches removeObjectForKey:[watch name]];
    
    NSMutableDictionary* returnInfo = [[NSMutableDictionary alloc]
                                       initWithObjectsAndKeys:[watch name],@"name", nil];
    
    for(NSString *connectCallback in connectCallbacks) {
        [self notifyKeepCallback: connectCallback
                      withStatus: CDVCommandStatus_ERROR
                     andWithData: returnInfo];
    }
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
