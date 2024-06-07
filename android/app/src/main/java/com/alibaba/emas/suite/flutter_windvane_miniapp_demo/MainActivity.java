package com.alibaba.emas.suite.flutter_windvane_miniapp_demo;

import android.content.Context;
import android.text.TextUtils;
import android.util.Log;

import androidx.annotation.NonNull;

import com.alibaba.module.android.core.common.AppUtils;
import com.alibaba.module.android.core.servicebus.service.ServiceManager;
import com.alibaba.module.android.mini.app.api.IMiniAppService;
import com.alibaba.module.android.mini.app.api.MiniAppConstants;
import com.alibaba.module.android.mini.app.api.MiniAppInfo;
import com.alibaba.module.android.mini.app.api.OnGetMiniAppsListener;
import com.alibaba.module.android.mini.app.api.OnLoadMiniAppListener;
import com.alibaba.module.android.mini.app.container.EmasMiniApp;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.List;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;
import mtopsdk.mtop.global.SwitchConfig;
import mtopsdk.mtop.intf.Mtop;
import mtopsdk.mtop.intf.MtopEnablePropertyType;
import mtopsdk.mtop.intf.MtopSetting;
import mtopsdk.security.LocalInnerSignImpl;

public class MainActivity extends FlutterActivity {
    private static final String WINDVANE_MINIAPP = "windvane_miniapp";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        GeneratedPluginRegistrant.registerWith(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor(), WINDVANE_MINIAPP).setMethodCallHandler(new MethodChannel.MethodCallHandler() {
            @Override
            public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
                if (call.method.equals("loadMiniApp")) {
                    loadMiniApp(call, result);
                } else if (call.method.equals("initWindVaneMiniApp")) {
                    initWindVaneMiniApp(call, result);
                } else if (call.method.equals("getMiniApps")) {
                    getMiniApps(call, result);
                } else {
                    result.notImplemented();
                }
            }
        });
    }

    private void loadMiniApp(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        String appId = call.argument("appId");

        if (!TextUtils.isEmpty(appId)) {
            IMiniAppService appService = ServiceManager.getInstance().getService(IMiniAppService.class.getName());
            if (appService != null) {
                appService.loadMiniApp(MainActivity.this, appId, new OnLoadMiniAppListener() {
                    @Override
                    public void onLoadMiniApp() {

                    }

                    @Override
                    public void onLoadSuccess(String appId) {
                        JSONObject json = new JSONObject();
                        try {
                            json.put("success", true);
                            result.success(json.toString());
                        } catch (JSONException e) {
                            result.success(json.toString());
                        }
                    }

                    @Override
                    public void onLoadFailed(String appId, int errorCode, String msg) {
                        JSONObject json = new JSONObject();
                        try {
                            json.put("success", false);
                            json.put("errorCode", errorCode);
                            json.put("msg", msg);
                            result.success(json.toString());
                        } catch (JSONException e) {
                            result.success(json.toString());
                        }
                    }
                });
            } else {
                JSONObject json = new JSONObject();
                try {
                    json.put("success", false);
                    json.put("errorCode", 11);
                    json.put("msg", "you need add service manger sdk");
                    result.success(json.toString());
                } catch (JSONException e) {
                    result.success(json.toString());
                }
            }
        } else {
            JSONObject json = new JSONObject();
            try {
                json.put("success", false);
                json.put("errorCode", MiniAppConstants.ERROR_CODE_APP_ID_EMPTY);
                json.put("msg", "appId is empty");
                result.success(json.toString());
            } catch (JSONException e) {
                result.success(json.toString());
            }
        }
    }

    private void initWindVaneMiniApp(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        EmasMiniApp.getInstance()
                .setOpenLog(false)
                .setTtid("aaa") //mock data
                .setAppVersion("1.0.0")
                .setZcacheEnable(true)
                .init(MainActivity.this.getApplication());

        initMtop(MainActivity.this);

        JSONObject json = new JSONObject();
        try {
            json.put("success", true);
            result.success(json);
        } catch (JSONException e) {
            result.success(json.toString());
        }
    }

    private void getMiniApps(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        IMiniAppService appService = ServiceManager.getInstance().getService(IMiniAppService.class.getName());
        if (appService != null) {
            appService.getMiniAppList(MainActivity.this, new OnGetMiniAppsListener() {
                @Override
                public void onSuccess(List<MiniAppInfo> miniAppInfos) {
                    JSONArray array = new JSONArray();
                    JSONObject json = new JSONObject();
                    try {
                        for (MiniAppInfo miniAppInfo : miniAppInfos) {
                            JSONObject miniApp = new JSONObject();
                            miniApp.put("appName", miniAppInfo.appName);
                            miniApp.put("appId", miniAppInfo.appId);
                            miniApp.put("appIcon", miniAppInfo.appIcon);

                            array.put(miniApp);
                        }

                        json.put("success", true);
                        json.put("miniApps", array);
                        result.success(json.toString());
                    } catch (JSONException e) {
                        result.success(json.toString());
                    }
                }

                @Override
                public void onFailed(int errorCode, String msg) {
                    JSONObject json = new JSONObject();
                    try {
                        json.put("success", false);
                        json.put("errorCode", errorCode);
                        json.put("msg", msg);
                        result.success(json.toString());
                    } catch (JSONException e) {
                        result.success(json.toString());
                    }
                }
            });
        } else {
            JSONObject json = new JSONObject();
            try {
                json.put("success", false);
                json.put("errorCode", 11);
                json.put("msg", "you need add service manger sdk");
                result.success(json.toString());
            } catch (JSONException e) {
                result.success(json.toString());
            }
        }
    }

    private void initMtop(Context context) {
        final String appKey = "20000002";   //mock appkey
        final String appSecret = "e7715dd9e24a1fd3117865dfcd4b6099"; //mock appsecret

        String domain = "aserver-intl.emas-poc.com";    //mock mtop domain

        SwitchConfig.getInstance().setGlobalSpdySwitchOpen(false);

        MtopSetting.setEnableProperty(Mtop.Id.INNER, MtopEnablePropertyType.ENABLE_NEW_DEVICE_ID, false);

        MtopSetting.setMtopDomain(Mtop.Id.INNER, domain, domain, domain);

        MtopSetting.setISignImpl(Mtop.Id.INNER, new LocalInnerSignImpl(appKey, appSecret));

        MtopSetting.setAppVersion(Mtop.Id.INNER, AppUtils.getAppVersion(context));
    }
}
