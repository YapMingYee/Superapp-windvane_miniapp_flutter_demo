import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'model/miniapp_model.dart';

class WindVaneMiniAppManager {
  static const MethodChannel channel = MethodChannel("windvane_miniapp");

  static Future<void> initWindVaneMiniApp() async {
    print('Miniapp appId: ${miniapp.appId}');
    try {
      await channel.invokeMethod("initWindVaneMiniApp");
    } catch (e) {
      print('Error initializing WindVane MiniApp: $e');
    }
  }

  static Future<List<WindvaneMiniapp>> getWindvaneMiniappList() async {
    try {
      final listResult = await channel.invokeMethod("getMiniApps", {});
      final jsonResult = jsonDecode(listResult);

      if (jsonResult['success']) {
        final miniApps = jsonResult['miniApps'] as List<dynamic>;
        return miniApps.map((miniApp) {
          return WindvaneMiniapp(
            miniApp['appName'],
            miniApp['appId'],
            miniApp['appIcon'],
          );
        }).toList();
      } else {
        throw Exception("Failed to get mini apps");
      }
    } catch (e) {
      print('Error fetching mini app list: $e');
      throw e;
    }
  }

  static Future<void> loadMiniapp(String appId) async {
    try {
      EasyLoading.show(
          status: 'Opening...', maskType: EasyLoadingMaskType.black);
      await channel.invokeMethod("loadMiniApp", {'appId': appId});
      EasyLoading.dismiss();
    } catch (e) {
      print('Error loading mini app: $e');
      EasyLoading.dismiss();
    }
  }
}
