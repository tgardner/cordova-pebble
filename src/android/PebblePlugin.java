package net.trentgardner.cordova.pebble;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CallbackContext;

import org.apache.cordova.CordovaWebView;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.UUID;
import java.lang.IllegalArgumentException;

import com.getpebble.android.kit.PebbleKit;
import com.getpebble.android.kit.util.PebbleDictionary;

public class PebblePlugin extends CordovaPlugin {

    private UUID appUuid;
    private ArrayList<CallbackContext> connectCallbacks;
    private ArrayList<CallbackContext> messageCallbacks;
    private PebbleKit.PebbleDataReceiver messageReceiver;
    private static int connectionId;

    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);

        connectCallbacks = new ArrayList<CallbackContext>();
        messageCallbacks = new ArrayList<CallbackContext>();

        PebbleKit.registerPebbleConnectedReceiver(getApplicationContext(), new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                connect();
            }
        });
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        if (action.equals("setAppUUID")) {
            try {
                String uuidString = args.getString(0);
                this.appUuid = UUID.fromString(uuidString);
                callbackContext.success();
            } catch (IllegalArgumentException e) {
                callbackContext.error(e.getMessage());
            }

            // Unregister any existing message listeners
            if(messageReceiver != null) {
                PebbleKit.registerReceivedDataHandler(getApplicationContext(), null);
                messageReceiver = null;
                messageCallbacks = new ArrayList<CallbackContext>();
            }
            
            return true;
        } else if (action.equals("onConnect")) {
            connectCallbacks.add(callbackContext);

            if(PebbleKit.isWatchConnected(getApplicationContext())) {
                connect();
            }

            return true;
        } else if (action.equals("onAppMessageReceived")) {
            if(messageReceiver == null) {
                messageReceiver = new MessageReceiver(this.appUuid);
                PebbleKit.registerReceivedDataHandler(getApplicationContext(), messageReceiver);
            }

            messageCallbacks.add(callbackContext);

            return true;
        } else if (action.equals("launchApp")) {
            PebbleKit.startAppOnPebble(getApplicationContext(), this.appUuid);
            callbackContext.success();

            return true;
        } else if (action.equals("killApp")) {
            PebbleKit.closeAppOnPebble(getApplicationContext(), this.appUuid);
            callbackContext.success();

            return true;
        } else if(action.equals("sendAppMessage")) {
            String json = args.getString(0);
            PebbleDictionary data = PebbleDictionary.fromJson(json);

            PebbleKit.sendDataToPebble(getApplicationContext(), this.appUuid, data);
            callbackContext.success();

            return true;
        }

        return false;
    }

    private void connect() {
        ++connectionId;

        JSONObject o = new JSONObject();

        try {
            o.put("handle", connectionId);
        } catch (JSONException e) {
            e.printStackTrace();
        }

        synchronized (connectCallbacks) {
            for(CallbackContext connectCallback : connectCallbacks) {
                keepCallback(connectCallback, o);
            }
        }
    }

    private void appMessageReceived(PebbleDictionary data) {
        JSONObject o = null;

        try {
            o = new JSONObject(data.toJsonString());
        } catch (JSONException e) {
            e.printStackTrace();
        }

        synchronized (messageCallbacks) {
            for(CallbackContext messageCallback : messageCallbacks) {
                keepCallback(messageCallback, o);
            }
        }
    }

    /**
     * Gets the application context from cordova's main activity.
     * @return the application context
     */
    private Context getApplicationContext() {
        return this.cordova.getActivity().getApplicationContext();
    }

    private static void keepCallback(final CallbackContext callbackContext,
                              JSONObject message) {
        PluginResult r = new PluginResult(PluginResult.Status.OK, message);
        r.setKeepCallback(true);
        callbackContext.sendPluginResult(r);
    }

    private final class MessageReceiver extends PebbleKit.PebbleDataReceiver {
        public MessageReceiver(UUID appUuid) {
            super(appUuid);
        }

        @Override
        public void receiveData(Context context, int i, PebbleDictionary pebbleDictionary) {
            appMessageReceived(pebbleDictionary);
        }
    }
}
