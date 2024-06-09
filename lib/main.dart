import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_windvane_miniapp_demo/windvane.dart';

import 'model/miniapp_model.dart';
import 'view/emas_refresh.dart';

void main() {
  runApp(MyApp());
  WindVaneMiniAppManager.initWindVaneMiniApp();
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

  bool _loading = true;
  bool _hasError = false;

  List<WindvaneMiniapp> _miniAppList = [];

  @override
  void initState() {
    super.initState();
    _fetchMiniApps();
  }

  Future<void> _fetchMiniApps() async {
    try {
      final miniApps = await WindVaneMiniAppManager.getWindvaneMiniappList();
      setState(() {
        _miniAppList = miniApps;
        _loading = false;
        _hasError = false;
      });
      _refreshController.finishRefresh();
    } catch (e) {
      setState(() {
        _loading = false;
        _hasError = true;
      });
    }
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _loading
          ? _buildLoadingView()
          : _hasError
              ? _buildErrorView()
              : _buildMiniAppListView(),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Loading...',
              style: TextStyle(color: Colors.blue, fontSize: 24)),
          CircularProgressIndicator(strokeWidth: 2.0),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Text('Failed to get Windvane mini app list',
          style: TextStyle(color: Colors.black)),
    );
  }

  Widget _buildMiniAppListView() {
    return EmasRefresh(
      controller: _refreshController,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 9.0),
        shrinkWrap: true,
        itemCount: _miniAppList.length,
        itemBuilder: (_, index) {
          return GestureDetector(
            onTap: () =>
                WindVaneMiniAppManager.loadMiniapp(_miniAppList[index].appId),
            child: MiniAppItem(miniapp: _miniAppList[index]),
          );
        },
      ),
      header: _buildRefreshHeader(),
      headerHeight: 60,
      onRefresh: _fetchMiniApps,
      footer: _buildRefreshFooter(),
      footerHeight: 20.0,
      onLoad: () async {},
    );
  }

  Widget _buildRefreshHeader() {
    return Container(
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
    );
  }

  Widget _buildRefreshFooter() {
    return Container(
      height: 20,
      alignment: Alignment.bottomCenter,
      child: const SizedBox(
        width: double.infinity,
        height: 10,
        child: LinearProgressIndicator(),
      ),
    );
  }
}

class MiniAppItem extends StatelessWidget {
  final WindvaneMiniapp miniapp;

  const MiniAppItem({Key? key, required this.miniapp}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
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
          const SizedBox(width: 10.0),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(miniapp.appName),
              const SizedBox(height: 10.0),
              Text(miniapp.appId),
            ],
          ),
        ],
      ),
    );
  }
}
