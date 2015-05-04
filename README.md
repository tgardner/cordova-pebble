cordova-pebble
=====================

> Implementation of the Pebble SDK for Cordova. Supports Android and iOS.

## Installation 

#### Cordova CLI

`cordova plugin add https://github.com/tgardner/cordova-pebble.git`

#### Telerik AppBuilder 

`appbuilder plugin fetch https://github.com/tgardner/cordova-pebble.git`

## Usage 

Set the UUID of your companion app, and register callbacks for connect/disconnect events from watches:


```javascript
Pebble.setAppUUID("cb2efd3c-4fa5-4bb9-b99b-9e0a1f3f9b62", 
    function() { console.log('success'); },
    function(event) { console.log('failure'); });
```

```javascript
Pebble.onConnect(
    function(event) { alert('connected'); }
    function(event) { alert('disconnected'); });
```

Launch your app:
```javascript
Pebble.launchApp(
    function() { console.log('success'); },
    function(event) { console.log('failure'); });
```

Send a message to the watch:
```javascript
Pebble.sendAppMessage({0: "hello"},
    function() { console.log('success'); },
    function(event) { console.log('failure'); });
```

Receive messages from the watch:
```javascript
Pebble.onAppMessageReceived(function(message){
    console.log(message);
});
```

Kill your app:
```javascript
Pebble.killApp(
    function() { console.log('success'); },
    function(event) { console.log('failure'); });
```

## Example
``` javascript
Pebble.setAppUUID("cb2efd3c-4fa5-4bb9-b99b-9e0a1f3f9b62", 
    function() { 
        Pebble.onConnect(function(event) { 
            Pebble.onAppMessageReceived(function(message){
                console.log(message);
            });

            Pebble.sendAppMessage({0: "hello"},
                function() { console.log('message sent'); });
        });
    }
);
```