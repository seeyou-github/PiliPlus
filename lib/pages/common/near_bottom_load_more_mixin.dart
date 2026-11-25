import 'package:material_ui/material_ui.dart';

/// 触底加载下一页
///
/// 用滚动通知 + 首屏补页代替在 `itemBuilder` 里做副作用：
/// - [onNearBottomScroll] 交给 `NotificationListener<ScrollNotification>`
/// - [scheduleFillViewport] 在 `build` 里调用，内容不足一屏时继续补页
///
/// 使用方需实现 [scrollControllerForLoadMore] 与 [loadMore]。
mixin NearBottomLoadMoreMixin<T extends StatefulWidget> on State<T> {
  /// 距底部小于该距离时开始加载下一页
  static const double loadMoreThreshold = 600;

  ScrollController get scrollControllerForLoadMore;

  void loadMore();

  /// 距底部还有 [loadMoreThreshold] 像素时触发加载
  bool onNearBottomScroll(ScrollNotification notification) {
    if (notification.depth == 0 &&
        notification.metrics.axis == Axis.vertical &&
        notification.metrics.extentAfter < loadMoreThreshold) {
      loadMore();
    }
    return false;
  }

  /// 首屏内容不足一屏时也继续加载下一页
  void scheduleFillViewport() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _fillViewport());
  }

  void _fillViewport() {
    if (!mounted) return;
    final scroll = scrollControllerForLoadMore;
    if (scroll.hasClients && scroll.position.extentAfter < loadMoreThreshold) {
      loadMore();
    }
  }
}
