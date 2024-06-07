import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

enum EmasRefreshLoadStatus {
  ///开始刷新状态
  start,

  /// 刷新/加载中
  handling,

  /// 刷新/加载结束中
  finish,

  /// 停止状态状态
  stop,
}

/// 当 [EmasRefresh] 下拉刷新或上拉加载状态变化时会回调
typedef OnRefreshOrLoadStatusChanged = void Function(dynamic state);

/// 当 [EmasRefresh] 发生滚动时会回调
typedef OnEmasScrollListener = void Function(ScrollMetrics metrics);

/// 用于构建下拉刷新元素
typedef EmasHeaderBuilder = Widget Function(
    StateSetter setter, BoxConstraints constraints);

/// 用于构建上拉加载元素
typedef EmasFooterBuilder = Widget Function(StateSetter setter);

/// 刷新、加载回调函数，返回任意值，将会结束刷新、加载
typedef EmasRefreshLoadCallback = Future Function();

abstract class _RefreshAction {
  void refresh();

  void finishRefresh();

  void finishLoad();

  void scrollTo(double position);

  void jumpTo(double position);

  bool mount();

  double offset();

  ScrollMetrics? position();
}

///EmasRefresh 控制器
class EmasRefreshController {
  late _RefreshAction? _refreshAction;

  /// 下拉刷新或者上拉加载的状态变化的回调
  OnRefreshOrLoadStatusChanged? onRefreshOrLoadStatusChanged;

  /// 当加载完成后，是否仍然保持在之前的位置，如果为true，则当前视图仍然保持在上拉加载前的位置
  bool keepPosOnLoadComplete = false;

  /// 当前滑动位置
  double get position {
    if (_refreshAction == null) {
      return 0.0;
    }

    return _refreshAction!.mount() ? _refreshAction!.offset() : 0.0;
  }

  /// 当前滑动信息。详见 [ScrollMetrics]。
  ScrollMetrics? get scrollMetrics {
    if (_refreshAction == null) {
      return null;
    }
    return _refreshAction!.mount() ? _refreshAction!.position() : null;
  }

  EmasRefreshController();

  /// 主动触发下拉刷新。
  void refresh() {
    if (_refreshAction != null && _refreshAction!.mount()) {
      _refreshAction!.refresh();
    }
  }

  /// 结束下拉刷新
  void finishRefresh() {
    if (_refreshAction != null && _refreshAction!.mount()) {
      _refreshAction!.finishRefresh();
    }
  }

  /// 结束上拉加载
  void finishLoad() {
    if (_refreshAction != null && _refreshAction!.mount()) {
      _refreshAction!.finishLoad();
    }
  }

  /// 滚动到指定位置
  void scrollTo(double position) {
    if (_refreshAction == null) {
      return;
    }

    if (!_refreshAction!.mount()) {
      return;
    }
    _refreshAction!.scrollTo(position);
  }

  /// 滚动指定距离
  void scrollBy(double offset) {
    if (_refreshAction == null) {
      return;
    }

    if (!_refreshAction!.mount()) {
      return;
    }
    _refreshAction!.scrollTo(_refreshAction!.offset() + offset);
  }

  /// 跳到指定位置
  ///
  /// Jump to the specified position
  void jumpTo(double position) {
    if (_refreshAction == null) {
      return;
    }

    if (!_refreshAction!.mount()) {
      return;
    }
    _refreshAction!.jumpTo(position);
  }

  void dispose() {
    _refreshAction = null;
    onRefreshOrLoadStatusChanged = null;
  }
}

class EmasRefresh extends StatefulWidget {
  /// 主要视图内容
  final Widget child;

  /// 下拉刷新时展示的view
  final Widget? header;

  /// 构建下拉刷新元素。会覆盖 [header] 配置。
  final EmasHeaderBuilder? headerBuilder;

  /// [header] 区域的高度
  final double headerHeight;

  /// 下拉刷新的触发距离，小于[headerHeight]时会默认以[headerHeight]的值为触发距离
  final double refreshTriggerOffset;

  /// 上拉加载时显示的view
  final Widget? footer;

  /// 构建上拉加载元素。会覆盖 [footer] 配置。
  final EmasFooterBuilder? footerBuilder;

  /// [footer] 区域的高度
  final double footerHeight;

  /// 上拉加载的触发距离, 小于[footerHeight]时默认以[footerHeight]的值为触发距离
  final double loadTriggerOffset;

  /// 触发刷新时会回调
  final EmasRefreshLoadCallback? onRefresh;

  /// 触发加载时会回调
  final EmasRefreshLoadCallback? onLoad;

  /// [EmasRefresh] 的控制器。详见 [EmasRefreshController]。
  final EmasRefreshController controller;

  ///滑动回调
  final OnEmasScrollListener? onScrollListener;

  const EmasRefresh({
    Key? key,
    required this.child,
    this.header,
    this.headerBuilder,
    this.refreshTriggerOffset = 60.0,
    this.footer,
    this.footerBuilder,
    this.loadTriggerOffset = 0.0,
    this.onRefresh,
    required this.controller,
    this.headerHeight = 50.0,
    this.footerHeight = 0.0,
    this.onLoad,
    this.onScrollListener,
  }) : super(key: key);

  @override
  _EmasRefreshState createState() => _EmasRefreshState();
}

class _EmasRefreshState extends State<EmasRefresh> implements _RefreshAction {
  late ValueNotifier<EmasRefreshLoadStatus> _refreshStatusNotifier;
  late ValueNotifier<EmasRefreshLoadStatus> _loadStatusNotifier;
  late ValueNotifier<bool> _startRefreshNotifier;
  late ValueNotifier<bool> _visibleNotifier;

  late ScrollPhysics _physics;
  late ScrollController _scrollController;

  Timer? loadTimer;
  Timer? hideTimer;

  GlobalKey headerGlobalKey = GlobalKey();

  double tempHeaderHeight = 0.0;

  @override
  void initState() {
    _refreshStatusNotifier = ValueNotifier(EmasRefreshLoadStatus.stop);
    _loadStatusNotifier = ValueNotifier(EmasRefreshLoadStatus.stop);
    _startRefreshNotifier = ValueNotifier(false);
    _visibleNotifier = ValueNotifier(false);
    _physics = _EmasScrollPhysics(footerHeight: widget.footerHeight);
    _scrollController = ScrollController();
    widget.controller._refreshAction = this;

    _refreshStatusNotifier.addListener(() async {
      if (widget.controller.onRefreshOrLoadStatusChanged != null) {
        widget.controller
            .onRefreshOrLoadStatusChanged!(_refreshStatusNotifier.value);
      }
      if (widget.onRefresh != null &&
          _refreshStatusNotifier.value == EmasRefreshLoadStatus.handling) {
        if (await widget.onRefresh!() != null) {
          finishRefresh();
        }
      }
    });
    _loadStatusNotifier.addListener(() async {
      if (widget.controller.onRefreshOrLoadStatusChanged != null) {
        widget.controller
            .onRefreshOrLoadStatusChanged!(_loadStatusNotifier.value);
      }
      if (widget.onLoad != null &&
          _loadStatusNotifier.value == EmasRefreshLoadStatus.handling) {
        if (await widget.onLoad!() != null) {
          finishLoad();
        }
      }
    });
    super.initState();
  }

  @override
  void refresh() {
    if (_refreshStatusNotifier.value == EmasRefreshLoadStatus.stop) {
      _scrollController.jumpTo(0.0);
      double offset = widget.refreshTriggerOffset > widget.headerHeight
          ? widget.refreshTriggerOffset
          : widget.headerHeight;
      _scrollController.animateTo(-offset,
          duration: const Duration(milliseconds: 300), curve: Curves.linear);
    }
  }

  @override
  void finishRefresh() {
    if (_refreshStatusNotifier.value == EmasRefreshLoadStatus.handling) {
      _refreshStatusNotifier.value = EmasRefreshLoadStatus.finish;
      _scrollController
          .animateTo(widget.headerHeight,
              duration: const Duration(milliseconds: 300), curve: Curves.linear)
          .whenComplete(() {
        _scrollController.jumpTo(0);
        _refreshStatusNotifier.value = EmasRefreshLoadStatus.stop;
        _visibleNotifier.value = false;
      });
    }
  }

  @override
  void finishLoad() {
    if (widget.controller.keepPosOnLoadComplete) {
      _loadStatusNotifier.value = EmasRefreshLoadStatus.finish;
      //重新滑动到原先的位置
      _scrollController
          .animateTo(
              _scrollController.position.maxScrollExtent - widget.footerHeight,
              duration: const Duration(milliseconds: 300),
              curve: Curves.linear)
          .whenComplete(() {
        _loadStatusNotifier.value = EmasRefreshLoadStatus.stop;
        _visibleNotifier.value = false;
      });
    } else {
      _loadStatusNotifier.value = EmasRefreshLoadStatus.finish;
      _loadStatusNotifier.value = EmasRefreshLoadStatus.stop;
      _visibleNotifier.value = false;
    }
  }

  @override
  void scrollTo(double position) {
    _scrollController.animateTo(position,
        duration: const Duration(milliseconds: 300), curve: Curves.linear);
  }

  @override
  void jumpTo(double position) {
    _scrollController.jumpTo(position);
  }

  @override
  bool mount() {
    return mounted;
  }

  @override
  double offset() {
    return _scrollController.offset;
  }

  @override
  ScrollMetrics? position() {
    return _scrollController.position;
  }

  void _onScrollUpdateNotification(
      ScrollUpdateNotification notification, double offset) {
    if (notification.dragDetails == null &&
        _refreshStatusNotifier.value == EmasRefreshLoadStatus.start) {
      _startRefreshNotifier.value = true;
    } else {
      _startRefreshNotifier.value = false;
    }

    double refreshTrigger = widget.refreshTriggerOffset > widget.headerHeight
        ? widget.refreshTriggerOffset
        : widget.headerHeight;

    bool hasHeader = (widget.header != null || widget.headerBuilder != null);
    if (_refreshStatusNotifier.value == EmasRefreshLoadStatus.stop &&
        _loadStatusNotifier.value == EmasRefreshLoadStatus.stop &&
        -offset * 2 >= refreshTrigger &&
        hasHeader) {
      _refreshStatusNotifier.value = EmasRefreshLoadStatus.start;
    }
  }

  void _handleLoad(ScrollNotification notification, double offset) {
    if (loadTimer != null) {
      loadTimer!.cancel();
    }

    var maxScrollExtent = _scrollController.position.maxScrollExtent;
    double extentAfter = maxScrollExtent - offset;
    double loadTrigger = widget.loadTriggerOffset > widget.footerHeight
        ? widget.loadTriggerOffset
        : widget.footerHeight;

    if (extentAfter == 0.0 &&
        _loadStatusNotifier.value == EmasRefreshLoadStatus.start) {
      _loadStatusNotifier.value = EmasRefreshLoadStatus.handling;
    } else if (offset - maxScrollExtent + widget.footerHeight > loadTrigger) {
      _loadStatusNotifier.value = EmasRefreshLoadStatus.start;
      loadTimer = Timer(const Duration(milliseconds: 100), () {
        if (_loadStatusNotifier.value == EmasRefreshLoadStatus.stop &&
            _refreshStatusNotifier.value == EmasRefreshLoadStatus.stop) {
          if (maxScrollExtent == offset) {
            _loadStatusNotifier.value = EmasRefreshLoadStatus.handling;
          } else {
            _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 200),
                curve: Curves.linear);
          }
        }
      });
    } else if (extentAfter < loadTrigger) {
      if (notification is UserScrollNotification ||
          notification is ScrollEndNotification) {
        loadTimer = Timer(const Duration(milliseconds: 100), () {
          if (_loadStatusNotifier.value == EmasRefreshLoadStatus.stop) {
            _scrollController.animateTo(maxScrollExtent - widget.footerHeight,
                duration: const Duration(milliseconds: 200),
                curve: Curves.linear);
          }
        });
      } else if (_loadStatusNotifier.value == EmasRefreshLoadStatus.start) {
        _loadStatusNotifier.value = EmasRefreshLoadStatus.stop;
      }
    }
  }

  void _onScrollStop(ScrollNotification notification) {
    bool isScrollEnd = (notification is UserScrollNotification ||
        notification is ScrollEndNotification);

    bool refreshLoadStop =
        _refreshStatusNotifier.value == EmasRefreshLoadStatus.stop &&
            _loadStatusNotifier.value == EmasRefreshLoadStatus.stop;

    if (isScrollEnd && refreshLoadStop && _visibleNotifier.value) {
      hideTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          _visibleNotifier.value = false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> slivers = <Widget>[];

    bool canHeaderShow =
        (widget.header != null || widget.headerBuilder != null) &&
            widget.headerHeight > 0;

    if (canHeaderShow) {
      slivers.add(_Header(
        headerHeight: widget.headerHeight,
        stateNotifier: _refreshStatusNotifier,
        visibleNotifier: _visibleNotifier,
        scrollToRefreshNotifier: _startRefreshNotifier,
        scrollController: _scrollController,
        child: widget.header!,
        build: widget.headerBuilder,
      ));
    }
    slivers.add(SliverToBoxAdapter(child: widget.child));

    bool canFooterShow =
        (widget.footer != null || widget.footerBuilder != null) &&
            widget.footerHeight > 0;
    if (canFooterShow) {
      slivers.add(Footer(
          child: SizedBox(
        height: widget.footerHeight,
        child: _Visible(
            visibleNotifier: _visibleNotifier,
            child: widget.footerBuilder == null
                ? widget.footer
                : StatefulBuilder(
                    builder: (context, setter) {
                      return widget.footerBuilder!(setter);
                    },
                  )),
      )));
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (hideTimer != null) {
          hideTimer!.cancel();
        }
        double offset = _scrollController.position.pixels;
        if (notification is ScrollStartNotification) {
          _visibleNotifier.value = true;
        } else if (notification is ScrollUpdateNotification) {
          _onScrollUpdateNotification(notification, offset);
        }
        if (widget.onScrollListener != null) {
          widget.onScrollListener!(notification.metrics);
        }

        if (_refreshStatusNotifier.value == EmasRefreshLoadStatus.stop &&
            canFooterShow &&
            notification.metrics.maxScrollExtent > 0.0) {
          _handleLoad(notification, offset);
        }

        _onScrollStop(notification);
        return false;
      },
      child: CustomScrollView(
        key: widget.key,
        physics: _physics,
        controller: _scrollController,
        slivers: slivers,
//        cacheExtent: widget.headerHeight,
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _scrollController.dispose();
    _refreshStatusNotifier.dispose();
    _loadStatusNotifier.dispose();
    _startRefreshNotifier.dispose();
    _visibleNotifier.dispose();
    widget.controller.dispose();
  }
}

class _Header extends StatefulWidget {
  final ValueNotifier<EmasRefreshLoadStatus> stateNotifier;
  final ValueNotifier<bool> scrollToRefreshNotifier;
  final ValueNotifier<bool> visibleNotifier;
  final ScrollController scrollController;
  final double headerHeight;
  final Widget child;
  final EmasHeaderBuilder? build;

  const _Header({
    Key? key,
    required this.stateNotifier,
    required this.scrollToRefreshNotifier,
    required this.visibleNotifier,
    required this.scrollController,
    required this.child,
    this.headerHeight = 50.0,
    this.build,
  }) : super(key: key);

  @override
  _HeaderState createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  late ValueNotifier<double> headerTopOffsetNotifier;

  @override
  void initState() {
    widget.stateNotifier.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    headerTopOffsetNotifier = ValueNotifier(0.0);
    super.initState();
  }

  @override
  void dispose() {
    headerTopOffsetNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SliverHeaderWidget(
      headerHeight: widget.headerHeight,
      refreshNotifier: widget.stateNotifier,
      headerTopOffsetNotifier: headerTopOffsetNotifier,
      startRefreshNotifier: widget.scrollToRefreshNotifier,
      child: LayoutBuilder(builder: (context, constraints) {
        double top = -widget.headerHeight + headerTopOffsetNotifier.value;
        return SizedBox(
            height: constraints.maxHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                    top: top,
                    child: _Visible(
                      visibleNotifier: widget.visibleNotifier,
                      child: widget.build != null
                          ? widget.build!(setState, constraints)
                          : widget.child,
                    )),
              ],
            ));
      }),
    );
  }
}

class _SliverHeaderWidget extends SingleChildRenderObjectWidget {
  final double headerHeight;
  final ValueNotifier<EmasRefreshLoadStatus> refreshNotifier;
  final ValueNotifier<double> headerTopOffsetNotifier;
  final ValueNotifier<bool> startRefreshNotifier;

  const _SliverHeaderWidget({
    Key? key,
    required Widget child,
    this.headerHeight = 50.0,
    required this.refreshNotifier,
    required this.headerTopOffsetNotifier,
    required this.startRefreshNotifier,
  }) : super(key: key, child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _HeaderSliverRenderObject(
      headerHeight: headerHeight,
      refreshNotifier: refreshNotifier,
      headerTopOffsetNotifier: headerTopOffsetNotifier,
      startRefreshNotifier: startRefreshNotifier,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, _HeaderSliverRenderObject renderObject) {
    renderObject
      ..height = headerHeight
      ..refreshNotifier = refreshNotifier
      ..headerTopOffsetNotifier = headerTopOffsetNotifier
      ..startRefreshNotifier = startRefreshNotifier;
  }
}

class _HeaderSliverRenderObject extends RenderSliverSingleBoxAdapter {
  ValueNotifier<EmasRefreshLoadStatus> refreshNotifier;
  ValueNotifier<double> headerTopOffsetNotifier;
  ValueNotifier<bool> startRefreshNotifier;

  double _headerHeight;

  double get height => _headerHeight;

  set height(double value) {
    if (height == value) return;
    _headerHeight = value;
    markNeedsLayout();
  }

  bool get isRefreshing =>
      refreshNotifier.value == EmasRefreshLoadStatus.handling;

  bool get isFinishing => refreshNotifier.value == EmasRefreshLoadStatus.finish;

  bool get isStartRefresh =>
      refreshNotifier.value == EmasRefreshLoadStatus.start;

  bool get isStop => refreshNotifier.value == EmasRefreshLoadStatus.stop;

  double get childHeight => child!.size.height;

  bool get isOverScroll => constraints.overlap < 0.0;

  bool _inFinish = false;

  double fixDiffTemp = -1;
  double fixHeaderTopDiffTemp = -1;
  double fixHeaderTopChildHeightDiffTemp = -1;

  _HeaderSliverRenderObject({
    double headerHeight = 50.0,
    required this.refreshNotifier,
    required this.headerTopOffsetNotifier,
    required this.startRefreshNotifier,
  }) : _headerHeight = headerHeight;

  void _onStartRefresh(double overOffset) {
    double layoutExtent = height;
    bool scrollToRefresh = startRefreshNotifier.value;
    if (scrollToRefresh) {
      layoutExtent = height;
      if (overOffset > height) {
        layoutExtent = height;
        headerTopOffsetNotifier.value = childHeight;
      } else {
        if (fixDiffTemp == -1) {
          fixDiffTemp = height - overOffset;
        }
        double fixLayoutExtent =
            fixDiffTemp - (fixDiffTemp * overOffset) / (height - fixDiffTemp);
        layoutExtent = (height - fixDiffTemp) + fixLayoutExtent;

        double headerOffset = headerTopOffsetNotifier.value;

        if (headerOffset < childHeight && fixHeaderTopDiffTemp == -1) {
          fixHeaderTopDiffTemp = headerOffset - height;
          fixHeaderTopChildHeightDiffTemp = overOffset;
        }
        if (fixHeaderTopDiffTemp != -1) {
          headerTopOffsetNotifier.value = height +
              fixHeaderTopDiffTemp *
                  overOffset /
                  fixHeaderTopChildHeightDiffTemp;
        } else {
          headerTopOffsetNotifier.value = childHeight;
        }
      }
    } else {
      layoutExtent = min(overOffset, height);
      headerTopOffsetNotifier.value = min(overOffset * 2.0, childHeight);
    }
    double paintExtent = min(childHeight, constraints.remainingPaintExtent);
    geometry = SliverGeometry(
      paintOrigin: -overOffset,
      paintExtent: paintExtent,
      maxPaintExtent: paintExtent,
      layoutExtent: min(layoutExtent, constraints.remainingPaintExtent),
    );
  }

  @override
  void performLayout() {
    //下拉过程中overlap会一直变化
    final double overlap =
        constraints.overlap < 0.0 ? constraints.overlap.abs() : 0.0;
    //对子组件进行布局
    child?.layout(
      constraints.asBoxConstraints(maxExtent: height + overlap),
      parentUsesSize: true,
    );
    //绘制高度
    double paintExtent;
    if (isStartRefresh) {
      _onStartRefresh(overlap);
    } else if (isRefreshing) {
      double layoutExtent = height;
      //绘制高度不超过最大可绘制空间
      paintExtent = min(childHeight, constraints.remainingPaintExtent);

      fixDiffTemp = -1;
      fixHeaderTopDiffTemp = -1;
      fixHeaderTopChildHeightDiffTemp = -1;
      headerTopOffsetNotifier.value = childHeight;
      geometry = SliverGeometry(
        paintOrigin: -overlap,
        paintExtent: paintExtent,
        maxPaintExtent: paintExtent,
        layoutExtent: min(layoutExtent, constraints.remainingPaintExtent),
      );
    } else if (isFinishing) {
      headerTopOffsetNotifier.value = overlap;
      //绘制高度不超过最大可绘制空间
      paintExtent = min(childHeight, constraints.remainingPaintExtent);
      geometry = SliverGeometry(
        paintOrigin: -min(constraints.scrollOffset, height),
        paintExtent: paintExtent,
        maxPaintExtent: paintExtent,
        layoutExtent: height,
      );
      _inFinish = true;
    } else if (_inFinish) {
      //绘制高度不超过最大可绘制空间
      paintExtent = min(childHeight, constraints.remainingPaintExtent);
      geometry = SliverGeometry(
        scrollExtent: constraints.scrollOffset,
        paintOrigin: -height,
        paintExtent: paintExtent,
        maxPaintExtent: paintExtent,
        layoutExtent: min(overlap, constraints.remainingPaintExtent),
        visible: overlap > 0,
        hasVisualOverflow: false,
      );
      if (constraints.scrollOffset == 0) {
        _inFinish = false;
      }
    } else {
      headerTopOffsetNotifier.value = overlap * 2.0;
      //绘制高度不超过最大可绘制空间
      paintExtent = min(childHeight, constraints.remainingPaintExtent);
      geometry = SliverGeometry(
        paintOrigin: -min(overlap, height),
        paintExtent: paintExtent,
        maxPaintExtent: paintExtent,
        layoutExtent: min(overlap, constraints.remainingPaintExtent),
        visible: overlap > 0,
        hasVisualOverflow: false,
      );
    }
    if (overlap == 0 && isStartRefresh) {
      SchedulerBinding.instance.addPostFrameCallback((time) {
        refreshNotifier.value = EmasRefreshLoadStatus.handling;
      });
    }
  }

  @override
  void paint(PaintingContext paintContext, Offset offset) {
    if (constraints.overlap < 0.0 ||
        childHeight > height ||
        refreshNotifier.value != EmasRefreshLoadStatus.stop) {
      paintContext.paintChild(child!, offset);
    }
  }
}

class Footer extends SingleChildRenderObjectWidget {
  const Footer({
    Key? key,
    Widget? child,
  }) : super(key: key, child: child);

  @override
  _FooterState createRenderObject(BuildContext context) => _FooterState();
}

class _FooterState extends RenderSliverToBoxAdapter {
  _FooterState({
    RenderBox? child,
  }) : super(child: child);

  @override
  void performLayout() {
    if (constraints.precedingScrollExtent <
        constraints.viewportMainAxisExtent) {
      geometry = const SliverGeometry(
        visible: false,
      );
    } else {
      super.performLayout();
    }
  }
}

class _EmasScrollPhysics extends BouncingScrollPhysics {
  final double footerHeight;

  const _EmasScrollPhysics({
    ScrollPhysics? parent,
    required this.footerHeight,
  }) : super(parent: parent);

  @override
  _EmasScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _EmasScrollPhysics(
      footerHeight: footerHeight,
      parent: buildParent(ancestor),
    );
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    assert(offset != 0.0);
    assert(position.minScrollExtent <= position.maxScrollExtent);
    if (!outOfRange(position)) return offset;

    //基本复用BouncingScrollPhysics逻辑，主要是加入对footer的判断
    final double overScrollPastStart =
        max(position.minScrollExtent - position.pixels, 0.0);
    final double overScrollPastEnd =
        max(position.pixels - (position.maxScrollExtent - (footerHeight)), 0.0);
    final double overScrollPast = max(overScrollPastStart, overScrollPastEnd);
    final bool easing = (overScrollPastStart > 0.0 && offset < 0.0) ||
        (overScrollPastEnd > 0.0 && offset > 0.0);
    final double friction = easing
        ? frictionFactor(
            (overScrollPast - offset.abs()) / position.viewportDimension)
        : frictionFactor(overScrollPast / position.viewportDimension);
    final double direction = offset.sign;

    return direction * _applyFriction(overScrollPast, offset.abs(), friction);
  }

  bool outOfRange(ScrollMetrics position) {
    return (position.pixels < position.minScrollExtent ||
        position.pixels > position.maxScrollExtent - (footerHeight));
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) {
    return true;
  }

  static double _applyFriction(
      double extentOutside, double absDelta, double gamma) {
    assert(absDelta > 0);
    double total = 0.0;
    if (extentOutside > 0) {
      final double deltaToLimit = extentOutside / gamma;
      if (absDelta < deltaToLimit) return absDelta * gamma;
      total += extentOutside;
      absDelta -= deltaToLimit;
    }
    return total + absDelta;
  }
}

class _Visible extends StatefulWidget {
  final Widget? child;
  final ValueNotifier<bool>? visibleNotifier;

  const _Visible({
    Key? key,
    this.child,
    this.visibleNotifier,
  }) : super(key: key);

  @override
  _VisibleState createState() => _VisibleState();
}

class _VisibleState extends State<_Visible> {
  @override
  void initState() {
    super.initState();
    widget.visibleNotifier?.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(
        visible: widget.visibleNotifier?.value ?? false, child: widget.child!);
  }
}
