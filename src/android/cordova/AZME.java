/*
 * Copyright (c) Microsoft Corporation.  All rights reserved.
 * Licensed under the MIT license. See License.txt in the project root for license information.
 */

package com.microsoft.azure.engagement.cordova;

import android.util.Log;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaActivity;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.PluginResult;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.os.Bundle;

import com.microsoft.azure.engagement.shared.EngagementDelegate;
import com.microsoft.azure.engagement.shared.EngagementShared;

public class AZME extends CordovaPlugin {

    private static final String pluginName = "CDVAZME";
    private static final String pluginVersion = "2.3.0";
    private static final String nativeSDKVersion = "4.1.0"; // to eventually retrieve from the SDK itself


    private EngagementShared engagementSharedSingleton;

    public CordovaInterface cordova = null;
    public CordovaWebView webView = null;
    public boolean isPaused = true;
    public String lastRedirect;
    private CallbackContext dataPushHandlerContext;

    private boolean lazyAreaLocation;
    private boolean realtimeLocation ;
    private boolean fineRealtimeLocation;
    private boolean backgroundReporting;
    private boolean foregroundReporting ;

    EngagementDelegate delegate = new EngagementDelegate() {

        @Override
        public void didReceiveDataPush(JSONObject _data) {
            PluginResult result = new PluginResult(PluginResult.Status.OK, _data);
            result.setKeepCallback(true);
            dataPushHandlerContext.sendPluginResult(result);
        }
    };

    public AZME() {
        engagementSharedSingleton = new EngagementShared();
    }


    public void initialize(CordovaInterface _cordova, CordovaWebView _webView) {
        CordovaActivity activity =  (CordovaActivity) _cordova.getActivity();

        final String invokeString = activity.getIntent().getDataString();
        if ( invokeString != null && !invokeString.equals("") ) {
            lastRedirect = invokeString;
        }
        super.initialize(_cordova, _webView);

        cordova = _cordova;
        webView  = _webView;


        try {
            ApplicationInfo ai = activity.getPackageManager().getApplicationInfo(activity.getPackageName(), PackageManager.GET_META_DATA);
            Bundle bundle = ai.metaData;

            boolean enableLog = bundle.getBoolean("engagement:log:test");
            engagementSharedSingleton.init(pluginName,pluginVersion,nativeSDKVersion);
            engagementSharedSingleton.setDebug(enableLog);

            lazyAreaLocation = bundle.getBoolean("AZME_LAZYAREA_LOCATION");
            realtimeLocation = bundle.getBoolean("AZME_REALTIME_LOCATION");
            fineRealtimeLocation = bundle.getBoolean("AZME_REALTIME_LOCATION");
            backgroundReporting= bundle.getBoolean("AZME_BACKGROUND_REPORTING");
            foregroundReporting = bundle.getBoolean("AZME_FOREGROUND_REPORTING");

            String connectionString = bundle.getString("AZME_ANDROID_CONNECTION_STRING");
            EngagementShared.backgroundReportingType background  = EngagementShared.backgroundReportingType.BACKGROUNDREPORTING_NONE;
            EngagementShared.locationReportingType locationReporting = EngagementShared.locationReportingType.LOCATIONREPORTING_NONE ;

            if (lazyAreaLocation)
                locationReporting = EngagementShared.locationReportingType.LOCATIONREPORTING_LAZY ;
            else
            if (realtimeLocation)
                locationReporting = EngagementShared.locationReportingType.LOCATIONREPORTING_REALTIME ;
            else
            if (fineRealtimeLocation)
                locationReporting = EngagementShared.locationReportingType.LOCATIONREPORTING_FINEREALTIME ;

            if (backgroundReporting)
                background = EngagementShared.backgroundReportingType.BACKGROUNDREPORTING_BACKGROUND;
            else
            if (foregroundReporting)
                background = EngagementShared.backgroundReportingType.BACKGROUNDREPORTING_FOREGROUND;

            engagementSharedSingleton.initialize(activity,connectionString,locationReporting,background);
            engagementSharedSingleton.setDelegate(delegate);

        } catch (PackageManager.NameNotFoundException e) {
            Log.e(EngagementShared.LOG_TAG,"Failed to load meta-data, NameNotFound: " + e.getMessage());
        } catch (NullPointerException e) {
            Log.e(EngagementShared.LOG_TAG,"Failed to load meta-data, NullPointer: " + e.getMessage());
        }

    }

    public boolean execute(String action, JSONArray args, CallbackContext callbackContext)   {

        if (action.equals("checkRedirect")) {

            String redirectType;
            try {
                redirectType = args.getString(0);
                if (redirectType.equals( "url")) {
                    callbackContext.success(lastRedirect);
                    lastRedirect = null;
                } else if (redirectType.equals("data")) {

                    PluginResult result = new PluginResult(PluginResult.Status.OK);
                    result.setKeepCallback(true);
                    callbackContext.sendPluginResult(result);
                    dataPushHandlerContext = callbackContext;
                    engagementSharedSingleton.enableDataPush();
                } else
                    callbackContext.error("unsupport type:" + redirectType);

            } catch (JSONException e) {
                callbackContext.error("missing arg for checkRedirect");
            }

            return true;
        }
        else if (action.equals("getStatus")) {

            final CallbackContext cb = callbackContext;

            engagementSharedSingleton.getStatus(new EngagementDelegate() {
                @Override
                public void onGetStatusResult(JSONObject _result) {
                    cb.success(_result);
                }
            });
            return true;
        } else if (action.equals("startActivity")) {

            try {
                String activityName = args.getString(0);
                String extraInfos = args.getString(1);
                engagementSharedSingleton.startActivity(activityName,extraInfos);
                callbackContext.success();
            } catch (JSONException e) {
                callbackContext.error("invalid args for startActivity");
            }
            return true;
        } else if (action.equals("endActivity")) {
            engagementSharedSingleton.endActivity();
            callbackContext.success();
            return true;
        } else if (action.equals("sendEvent")) {

            try {
                String eventName = args.getString(0);
                String extraInfos = args.getString(1);
                engagementSharedSingleton.sendEvent(eventName, extraInfos);
                callbackContext.success();
            } catch (JSONException e) {
                callbackContext.error("invalid args for sendEvent");
            }
            return true;
        } else if (action.equals("startJob")) {

            try {
                String jobName = args.getString(0);
                String extraInfos = args.getString(1);
                engagementSharedSingleton.startJob(jobName, extraInfos);
                callbackContext.success();

            } catch (JSONException e) {
                callbackContext.error("invalid args for startJob");
            }
            return true;
        } else if (action.equals("endJob")) {

            try {
                String jobName = args.getString(0);
                engagementSharedSingleton.endJob(jobName);
                callbackContext.success();
            } catch (JSONException e) {
                callbackContext.error("invalid args for endJob");
            }
            return true;
        } else if (action.equals("sendSessionEvent")) {

            try {
                String eventName = args.getString(0);
                String extraInfos = args.getString(1);
                engagementSharedSingleton.sendSessionEvent(eventName, extraInfos);
                callbackContext.success();

            } catch (JSONException e) {
                callbackContext.error("invalid args for sendSessionEvent");
            }
            return true;
        } else if (action.equals("sendSessionError")) {

            try {
                String error = args.getString(0);
                String extraInfos = args.getString(1);
                engagementSharedSingleton.sendSessionError(error, extraInfos);
                callbackContext.success();

            } catch (JSONException e) {
                callbackContext.error("invalid args for sendSessionError");
            }
            return true;
        } else if (action.equals("sendError")) {

            try {
                String error = args.getString(0);
                String extraInfos = args.getString(1);
                engagementSharedSingleton.sendError(error, extraInfos);
                callbackContext.success();

            } catch (JSONException e) {
                callbackContext.error("invalid args for sendError");
            }
            return true;
       } else if (action.equals("sendJobEvent")) {

            try {
                String eventName = args.getString(0);
                String jobName = args.getString(1);
                String extraInfos = args.getString(2);
                engagementSharedSingleton.sendJobEvent(eventName, jobName, extraInfos);
                callbackContext.success();

            } catch (JSONException e) {
                callbackContext.error("invalid args for sendJobEvent");
            }
            return true;
        } else if (action.equals("sendJobError")) {

            try {
                String error = args.getString(0);
                String jobName = args.getString(1);
                String extraInfos = args.getString(2);
                engagementSharedSingleton.sendJobError(error, jobName, extraInfos);
                callbackContext.success();

            } catch (JSONException e) {
                callbackContext.error("invalid args for sendJobError");
            }
            return true;
        } else if (action.equals("sendAppInfo")) {

            try {
                String extraInfos = args.getString(1);
                engagementSharedSingleton.sendAppInfo(extraInfos);
                callbackContext.success();
            } catch (JSONException e) {
                callbackContext.error("invalid args for sendAppInfo");
            }
            return true;
        } else if (action.equals("registerForPushNotification")) {
            // does nothing on Android
            callbackContext.success();
            return true;
        }
         else if (action.equals("requestPermissions")) {

            JSONArray permissions = new JSONArray();
            if (realtimeLocation || fineRealtimeLocation)
                permissions.put("ACCESS_FINE_LOCATION");
            else if (lazyAreaLocation)
                permissions.put("ACCESS_COARSE_LOCATION");

            JSONObject ret =  engagementSharedSingleton.requestPermissions(permissions);
            if (!ret.has("error"))
                callbackContext.success(ret);
            else
            {
                String errString = null;
                try {
                    errString = ret.getString("error");
                } catch (JSONException e) {
                    Log.e(EngagementShared.LOG_TAG,"missing error tag");
                }
                callbackContext.error(errString);
            }

            return true;
        }
      
        String str = "Unrecognized Command : "+action;
        Log.e(EngagementShared.LOG_TAG,str);
        callbackContext.error(str);
        return false;
    }

    public void onPause(boolean multitasking) {

        engagementSharedSingleton.onPause();
    }

    public void onResume(boolean multitasking) {

        engagementSharedSingleton.onResume();
    }

    public void onRequestPermissionResult(int requestCode, String[] permissions, int[] grantResults) throws JSONException {
        
        if (requestCode == 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED)
          engagementSharedSingleton.refreshPermissions();
    }

}
