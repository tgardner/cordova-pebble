var exec = cordova.require('cordova/exec'),
    service = 'pebble';

function errorCallback(callback) {
    return callback || function(e) {
        console.log(e);
    };
}

var Pebble = {
    setAppUUID: function(uuid, success, failure) {

        exec(
            success,
            errorCallback(failure),
            service,
            'setAppUUID',
            [ uuid ]
        );

    },

    onConnect: function(success, failure) {

        exec(
            success,
            errorCallback(failure),
            service,
            'onConnect',
            []
        );

    },

    launchApp: function(success, failure) {

        exec(
            success,
            errorCallback(failure),
            service,
            'launchApp',
            []
        );

    },
    killApp: function(success, failure) {

        exec(
            success,
            errorCallback(failure),
            service,
            'killApp',
            []
        );

    },


    sendAppMessage: function(appMessage, success, failure) {

        exec(
            success,
            errorCallback(failure),
            service,
            'sendAppMessage',
            [ JSON.stringify(appMessage) ]
        );

    },

    onAppMessageReceived: function(success, failure) {

        exec(
            messageCallback,
            errorCallback(failure),
            service,
            'onAppMessageReceived',
            []
        );
        
    }

};

module.exports = Pebble;
