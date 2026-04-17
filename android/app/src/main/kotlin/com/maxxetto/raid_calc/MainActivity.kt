package com.maxxetto.raid_calc

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "raid_calc/bootstrap"
        ).setMethodCallHandler { call, result ->
            if (call.method != "getAndroidRevenueCatApiKey") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            try {
                val appInfo = packageManager.getApplicationInfo(
                    packageName,
                    PackageManager.GET_META_DATA
                )
                val key = appInfo.metaData
                    ?.getString("revenuecat_android_api_key")
                    ?.trim()
                    .orEmpty()
                result.success(key)
            } catch (e: Exception) {
                result.error("META_DATA_ERROR", e.message, null)
            }
        }
    }
}
