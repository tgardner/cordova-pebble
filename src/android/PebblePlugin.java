package net.trentgardner.cordova.pebble;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CallbackContext;

import org.apache.cordova.CordovaWebView;
import org.apache.cordova.LOG;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.UUID;
import java.lang.IllegalArgumentException;

import com.getpebble.android.kit.PebbleKit;
import com.getpebble.android.kit.util.PebbleDictionary;

public class PebblePlugin extends CordovaPlugin {
    private final String TAG = this.getClass().getSimpleName();

    private UUID appUuid;
    private ArrayList<CallbackContext> connectCallbacks;
    private ArrayList<CallbackContext> messageCallbacks;
    private PebbleKit.PebbleDataReceiver messageReceiver;
    private static int connectionId;

    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);

        LOG.d(TAG, "initialize");

        connectCallbacks = new ArrayList<CallbackContext>();
        messageCallbacks = new ArrayList<CallbackContext>();

        PebbleKit.registerPebbleConnectedReceiver(getApplicationContext(), new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                connect();
            }
        });

        PebbleKit.registerPebbleDisconnectedReceiver(getApplicationContext(), new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                disconnect();
            }
        });
    }

    @Override
    public void onDestroy() {
        LOG.d(TAG, "onDestroy");

        if(messageReceiver != null) {
            unregisterMessageReceiver();
        }

        PebbleKit.registerPebbleConnectedReceiver(getApplicationContext(), null);
        PebbleKit.registerPebbleDisconnectedReceiver(getApplicationContext(), null);

        super.onDestroy();
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        LOG.d(TAG, "execute - %s", action);

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
                unregisterMessageReceiver();
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
                registerMessageReceiver();
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
            sendData(callbackContext, json);

            return true;
        }

        return false;
    }

    private void sendData(CallbackContext callbackContext, String json) {
        try {
            JSONObject object = new JSONObject(json);
            PebbleDictionary data = new PebbleDictionary();
            for(Iterator<String> keys = object.keys(); keys.hasNext();) {
                String key = keys.next();
                Object val = object.get(key);
                if(val instanceof Integer) {
                    data.addInt32(Integer.parseInt(key), (Integer)val);
                } else {
                    data.addString(Integer.parseInt(key), (String)val);
                }
            }

            PebbleKit.sendDataToPebble(getApplicationContext(), this.appUuid, data);

            callbackContext.success();
        } catch (JSONException e) {
            callbackContext.error(e.getMessage());
        }
    }

    private void connect() {
        LOG.d(TAG, "connect");
        ++connectionId;

        JSONObject o = new JSONObject();

        try {
            o.put("handle", connectionId);
        } catch (JSONException e) {
            e.printStackTrace();
        }

        synchronized (connectCallbacks) {
            for(CallbackContext connectCallback : connectCallbacks) {
                keepSuccessCallback(connectCallback, o);
            }
        }
    }

    private void disconnect() {
        LOG.d(TAG, "disconnect");

        synchronized (connectCallbacks) {
            for(CallbackContext connectCallback : connectCallbacks) {
                keepCallback(PluginResult.Status.ERROR, connectCallback, null);
            }
        }
    }

    private void appMessageReceived(PebbleDictionary data) {
        JSONObject result = new JSONObject();

        try {
            String json = data.toJsonString();
            JSONArray values = new JSONArray(json);
            for(int i = 0; i < values.length(); ++i) {
                JSONObject value = values.getJSONObject(i);
                String key = String.valueOf(value.getInt("key"));
                String type = value.getString("type");

                if(type.equals("int") || value.equals("uint")) {
                    result.put(key, value.getInt("value"));
                } else {
                    result.put(key, value.getString("value"));
                }
            }
        } catch (JSONException e) {
            e.printStackTrace();
        }

        synchronized (messageCallbacks) {
            for(CallbackContext messageCallback : messageCallbacks) {
                keepSuccessCallback(messageCallback, result);
            }
        }
    }

    private void unregisterMessageReceiver() {
        PebbleKit.registerReceivedDataHandler(getApplicationContext(), null);
        messageReceiver = null;
    }

    private void registerMessageReceiver() {
        messageReceiver = new MessageReceiver(this.appUuid);
        PebbleKit.registerReceivedDataHandler(getApplicationContext(), messageReceiver);
    }

    /**
     * Gets the application context from cordova's main activity.
     * @return the application context
     */
    private Context getApplicationContext() {
        return this.cordova.getActivity().getApplicationContext();
    }

    private static void keepSuccessCallback(CallbackContext callbackContext,
                                            JSONObject obj) {

        keepCallback(PluginResult.Status.OK, callbackContext, obj);

    }

    private static void keepCallback(PluginResult.Status status,
                                     CallbackContext callbackContext,
                                     JSONObject obj) {

        PluginResult r = new PluginResult(status, obj);
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
