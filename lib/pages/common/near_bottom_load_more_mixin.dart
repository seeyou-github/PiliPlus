import 'package:material_ui/material_ui.dart';

/// 触底加载下一页
///
/// 用滚动通知 + 首屏补页代替在 `itemBuilder` 里做副作用：
/// - [onNearBottomScroll] 交给 `NotificationListener<ScrollNotification>`
/// - [scheduleFillViewport] 在 `build` / 列表更新后调用，内容不足一屏时继续补页
///
/// 使用方需实现 [scrollControllerForLoadMore] 与 [loadMore]。
mixin NearBottomLoadMoreMixin<T extends StatefulWidget> on State<T> {
  /// 距底部小于该距离时开始加载下一页
  static const double loadMoreThreshold = 600;

  ScrollController get scrollControllerForLoadMore;

  /// 触发一次加载
  ///
  /// [byUser] 为 true 表示用户主动滑到底部（不受自动补屏的退避限制）。
  /// 返回 true 表示本次**同步**补充了内容（例如放出本地缓存），
  /// 此时会继续检查视口，直到内容填满屏幕或没有更多可补。
  bool loadMore({bool byUser = false});

  /// 距底部还有 [loadMoreThreshold] 像素时触发加载
  bool onNearBottomScroll(ScrollNotification notification) {
    if (notification.depth == 0 &&
        notification.metrics.axis == Axis.vertical &&
        notification.metrics.extentAfter < loadMoreThreshold) {
      loadMore(byUser: true);
    }
    return false;
  }

  /// 首屏内容不足一屏时也继续补内容
  void scheduleFillViewport() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _fillViewport());
  }

  void _fillViewport() {
    if (!mounted) return;
    final scroll = scrollControllerForLoadMore;
    if (!scroll.hasClients) return;
    if (scroll.position.extentAfter >= loadMoreThreshold) return;
    // 只有同步补到内容才继续检查；异步请求期间的重复触发由控制器的忙碌标记挡掉
    if (loadMore()) scheduleFillViewport();
  }
}
