cordova-pebble
=====================

Implementation of the Pebble SDK for Cordova.

### Usage ###

Set the UUID of your companion app, and register callbacks for connect/disconnect events from watches:

```javascript
Pebble.onConnect('<your-pebble-app-uuid>',
    function(event) {
        alert('watch connected');
    }
    function(event) {
        alert('watch disconnected');
    }
);
```

Launch your app:

```javascript
Pebble.launchApp(
    function(result){
        console.log(result);
    },
    function(err){
        alert(err);
    }
);
```

Send a message to the watch:
```javascript
Pebble.sendAppMessage({0: "hello"},
    function(message){
        console.log('success');
    },
    function(err){
        alert(err);
    }
);
```

Receive messages from the watch:
```javascript
Pebble.onDataReceived(function(message){
    console.log(message);
});
```

Kill your app:

```javascript
Pebble.killApp(
    function(result){
        console.log(result);
    },
    function(err){
        alert(err);
    }
);
```

