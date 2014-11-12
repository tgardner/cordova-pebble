var exec = cordova.require('cordova/exec'),
    service = 'pebble';

var Pebble = {

    onConnect: function(uuid, connectCallback, disconnectCallback) {

        exec(
            connectCallback,
            disconnectCallback,
            service,
            'onConnect',
            [ uuid ]
        );

    },

    launchApp: function(success, failure) {

        exec(
            success,
            failure,
            service,
            'launchApp',
            []
        );

    },
    killApp: function(success, failure) {

        exec(
            success,
            failure,
            service,
            'killApp',
            []
        );

    },


    sendAppMessage: function(appMessage, connectCallback, disconnectCallback) {

        exec(
            connectCallback,
            disconnectCallback,
            service,
            'sendAppMessage',
            [ JSON.stringify(appMessage) ]
        );

    },

    onAppMessageReceived: function(messageCallback, errorCallback) {

        exec(
            messageCallback,
            errorCallback,
            service,
            'onAppMessageReceived',
            []
        );
        
    }

};


module.exports = Pebble;
