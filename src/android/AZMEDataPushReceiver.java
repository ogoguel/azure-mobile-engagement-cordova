 
package com.microsoft.azure.engagement.cordova;

import java.util.Iterator;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaActivity;
import org.apache.cordova.CordovaWebView;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.os.Bundle;

import com.microsoft.azure.engagement.EngagementConfiguration;
import com.microsoft.azure.engagement.EngagementAgent;
import com.microsoft.azure.engagement.EngagementAgentUtils;
import com.microsoft.azure.engagement.reach.EngagementReachDataPushReceiver;
import com.microsoft.azure.engagement.cordova.AZME;

 public class AZMEDataPushReceiver extends EngagementReachDataPushReceiver
 {
    public static String Category;
    public static String Body;

    @Override
    protected Boolean onDataPushStringReceived(Context context, String category, String body)
    {
        Log.d(AZME.LOG_TAG, "String data push message received: " + body);
        if (AZME.webView != null)
            AZME.webView.sendJavascript("AzureEngagement.handleDataPush('"+category+"','"+body+"')");
        else
            Log.e(AZME.LOG_TAG, "dataPush discarded");

        return true;
    }

    @Override
    protected Boolean onDataPushBase64Received(Context context, String category, byte[] decodedBody, String encodedBody)
    {
        Log.d(AZME.LOG_TAG, "String data64 push message received: " + encodedBody);

        if (AZME.webView != null)
            AZME.webView.sendJavascript("AzureEngagement.handleDataPush('"+category+"','"+encodedBody+"')");
        else
            Log.e(AZME.LOG_TAG, "dataPush64 discarded");

        return true;
    }
 }