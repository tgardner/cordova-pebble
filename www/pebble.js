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


    sendAppMessage: function(message, success, failure) {
        if(typeof(message) !== 'object') {
            message = {0 : message};
        }

        exec(
            success,
            errorCallback(failure),
            service,
            'sendAppMessage',
            [ JSON.stringify(message) ]
        );

    },

    onAppMessageReceived: function(success, failure) {

        exec(
            success,
            errorCallback(failure),
            service,
            'onAppMessageReceived',
            []
        );
        
    }

};

module.exports = Pebble;
