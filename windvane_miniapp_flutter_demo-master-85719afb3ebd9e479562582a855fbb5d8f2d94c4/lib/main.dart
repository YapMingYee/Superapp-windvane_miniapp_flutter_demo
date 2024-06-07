import 'dart:convert';


import 'package:flutter/material.dart';
import 'package:flutter_windvane_miniapp_demo/model/miniapp_model.dart';
import 'package:flutter_windvane_miniapp_demo/windvane.dart';

import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'view/emas_refresh.dart';


void main() {
  runApp(MyApp());
  configLoading();
  WindVaneMiniAppManager.channel.invokeMethod("initWindVaneMiniApp");
}

void configLoading() {
  EasyLoading.instance
    ..displayDuration = const Duration(milliseconds: 2000)
    ..indicatorType = EasyLoadingIndicatorType.fadingCircle
    ..loadingStyle = EasyLoadingStyle.dark
    ..indicatorSize = 45.0
    ..radius = 10.0
    ..progressColor = Colors.yellow
    ..backgroundColor = Colors.green
    ..indicatorColor = Colors.yellow
    ..textColor = Colors.yellow
    ..maskColor = Colors.blue.withOpacity(0.5)
    ..userInteractions = true
    ..dismissOnTap = false;
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
      builder: EasyLoading.init(),
    );
  }
}


class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final EmasRefreshController _refreshController = EmasRefreshController();

  late bool _loading;
  late bool _hasError;

  final List<WindvaneMiniapp> _miniAppList = [];

  void getWindvaneMiniappList() {
    WindVaneMiniAppManager.channel
        .invokeMethod("getMiniApps", {}).then((listResult) {
      try {
        Map<String, dynamic> jsonResult = jsonDecode(listResult);
        var success = jsonResult['success'];
        print('list: ' + jsonResult.toString());
        if (success) {
          List<dynamic> miniApps = jsonResult['miniApps'];
          _miniAppList.clear();
          for (dynamic miniApp in miniApps) {
            var appName = miniApp['appName'];
            var appId = miniApp['appId'];
            var appIcon = miniApp['appIcon'];
            WindvaneMiniapp windvaneMiniapp =
                WindvaneMiniapp(appName, appId, appIcon);
            _miniAppList.add(windvaneMiniapp);
          }
          setState(() {
            _loading = false;
            _hasError = false;
          });
          try {
            _refreshController.finishRefresh();
          } catch (e) {
            
          }
        } else {
          setState(() {
            _loading = false;
            _hasError = true;
          });
        }
      } catch (e) {
        print(e);
        setState(() {
          _hasError = true;
          _loading = false;
        });
      }
    });
  }

  void loadMiniapp(String appId) {
    try {
      EasyLoading.show(
        status: 'Opening...',
        maskType: EasyLoadingMaskType.black,
      );

      WindVaneMiniAppManager.channel.invokeMethod(
          "loadMiniApp", {'appId': appId}).then((value) => EasyLoading.dismiss());
    } catch (e) {
    }
  }

  @override
  void initState() {
    super.initState();
    _loading = true;
    _hasError = false;
    getWindvaneMiniappList();
  }


  @override
  void dispose() {
    super.dispose();
    _refreshController.dispose();
  }

  Widget _refreshView() {
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Loading...',
              style: TextStyle(color: Colors.blue, fontSize: 24),
            ),
            CircularProgressIndicator(strokeWidth: 2.0),
          ],
        ),
      );
    }

    if (_hasError) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        alignment: Alignment.center,
        child: Text(
          'Failed to get Windvane mini app list',
          style: TextStyle(color: Colors.black),
        ),
      );
    }

    return Container(
      height: double.infinity,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(6.0)),
        boxShadow: [
          BoxShadow(
              color: Color(0x4d3754AA), blurRadius: 6.0, offset: Offset(3, 3)),
        ],
      ),
      child: StatefulBuilder(
        builder: (context, setter) {
          return EmasRefresh(
            controller: _refreshController,
            child: ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 9.0),
                shrinkWrap: true,
                itemCount: _miniAppList.length,
                itemBuilder: (_, index) {
                  return GestureDetector(
                    onTap: () {
                      loadMiniapp(_miniAppList[index].appId);
                    },
                    child: Item(
                      width: double.infinity,
                      height: 100.0,
                      miniapp: _miniAppList[index],
                    ),
                  );
                }),
            header: Container(
              width: 75.0,
              height: 75.0,
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(),
              child: OverflowBox(
                maxHeight: 100.0,
                maxWidth: 100.0,
                child: Image.asset(
                  "assets/refresh1.gif",
                  width: 100.0,
                  height: 100.0,
                  fit: BoxFit.fitHeight,
                ),
              ),
            ),
            headerHeight: 60,
            onRefresh: () async {
              getWindvaneMiniappList();
            },
            footer: Container(
                height: 20,
                alignment: Alignment.bottomCenter,
                child: const SizedBox(
                  width: double.infinity,
                  height: 10,
                  child: LinearProgressIndicator(),
                )),
            footerHeight: 20.0,
            onLoad: () async {
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _refreshView(),
    );
  }
}

class Item extends StatelessWidget {
  final double width;
  final double height;
  final WindvaneMiniapp miniapp;

  const Item({
    Key? key,
    this.width = double.infinity,
    this.height = 100,
    required this.miniapp,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
        width: width,
        height: height,
        margin: const EdgeInsets.only(top: 12.0),
        padding: const EdgeInsets.all(5.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.all(Radius.circular(5.0)),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.shade400,
                blurRadius: 3.0,
                offset: const Offset(2.0, 2.0)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.network(miniapp.appIcon),
            const SizedBox(
              width: 10.0,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  child: Text('${miniapp.appName}'),
                ),
                const SizedBox(height: 10.0),
                Container(
                  child: Text('${miniapp.appId}'),
                ),
              ],
            )
          ],
        ));
  }
}
