import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/http/live.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/local_feed.dart';
import 'package:PiliPlus/models/local/local_follow_item.dart';
import 'package:PiliPlus/models/member/info.dart' show LiveRoom;
import 'package:PiliPlus/models_new/member/search_archive/vlist.dart';
import 'package:PiliPlus/pages/common/common_controller.dart'
    show RefreshImplMixin, ScrollOrRefreshMixin;
import 'package:PiliPlus/utils/local_blacklist.dart';
import 'package:PiliPlus/utils/local_library.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/widgets.dart' show ScrollController;
import 'package:get/get.dart';

/// 本地关注投稿流（未登录时使用）
///
/// 只拉取本地关注 UP 的投稿（App 端投稿接口，按发布时间倒序），
/// 多 UP 结果合并去重后按 `pubdate` 倒序展示，逻辑参考 PipePipe 的本地 feed：
/// 逐订阅抓取 → 合并 → 排序。进入页面与下拉时都会重新抓取，并同时刷新直播状态。
class LocalFeedController extends GetxController
    with ScrollOrRefreshMixin, RefreshImplMixin {
  /// 每批并发请求的 UP 数量
  static const _batchSize = 5;

  /// 单次查询直播状态的最大 uid 数量
  static const _liveBatchSize = 50;

  @override
  final ScrollController scrollController = ScrollController();

  final items = <VListItemModel>[].obs;
  final loading = true.obs;
  final isEnd = false.obs;

  /// 每个 UP 最近刷新后新增的投稿数（未读角标）
  final updateCounts = <int, int>{}.obs;

  /// 本地关注中正在直播的 UP（mid -> 直播间）
  final liveRooms = <int, LiveRoom>{}.obs;

  bool _busy = false;
  bool _initialized = false;

  final Map<String, VListItemModel> _map = {};
  final Map<int, int> _lastPubdate = {};

  /// 每个 UP 的下一页游标，App 投稿接口使用 aid 游标而非页码。
  final Map<int, int?> _cursors = {};

  Worker? _followWorker;

  List<LocalFollowItem> get follows => LocalLibrary.follows;

  @override
  void onInit() {
    super.onInit();
    // 首次关注后立即拉取投稿，避免动态页停留在「还没有本地关注」
    _followWorker = ever(LocalLibrary.followCount, (_) => onRefresh());
    // 进入本地关注模式即刷新一批投稿，同时刷新 UP 的直播状态
    onRefresh();
  }

  @override
  void onClose() {
    _followWorker?.dispose();
    scrollController.dispose();
    super.onClose();
  }

  void toTopAndRefresh() {
    if (scrollController.hasClients) animateToTop();
    showRefresh();
  }

  String _keyOf(VListItemModel item) =>
      item.bvid ?? (item.aid != null ? 'av${item.aid}' : item.title);

  /// 批量查询本地关注 UP 的直播状态，失败静默忽略，不影响投稿流
  Future<void> _queryLiveRooms(List<LocalFollowItem> follows) async {
    final rooms = <int, LiveRoom>{};
    try {
      final mids = follows.map((e) => e.mid).toList();
      for (var i = 0; i < mids.length; i += _liveBatchSize) {
        final chunk = mids.skip(i).take(_liveBatchSize).toList();
        final res = await LiveHttp.liveStatusByUids(chunk);
        if (res case Success(:final response)) {
          rooms.addAll(response);
        }
      }
    } catch (_) {}
    liveRooms.value = rooms;
  }

  /// 根据每个 UP 上次看到的投稿时间计算刷新后的更新数量
  void _updateCounts(List<VListItemModel> list) {
    if (!_initialized) {
      // 首次加载只记录基线，不把历史投稿标成更新
      _initialized = true;
    } else {
      final counts = <int, int>{};
      for (final item in list) {
        final mid = item.owner.mid;
        if (mid == null) continue;
        final pubdate = item.pubdate ?? 0;
        if (pubdate > (_lastPubdate[mid] ?? 0)) {
          counts[mid] = (counts[mid] ?? 0) + 1;
        }
      }
      updateCounts.value = counts;
    }
    for (final item in list) {
      final mid = item.owner.mid;
      if (mid == null) continue;
      final pubdate = item.pubdate ?? 0;
      if (pubdate > (_lastPubdate[mid] ?? 0)) _lastPubdate[mid] = pubdate;
    }
  }

  /// [refresh] 为 true 时回到第一页重新抓取，并顺带刷新直播状态
  Future<void> queryData({bool refresh = false}) async {
    if (_busy) return;
    final follows = this.follows;
    if (follows.isEmpty) {
      _map.clear();
      items.clear();
      updateCounts.value = const <int, int>{};
      liveRooms.value = const <int, LiveRoom>{};
      loading.value = false;
      isEnd.value = true;
      return;
    }

    if (refresh) {
      isEnd.value = false;
      _busy = true;
      _cursors.clear();
      // 刷新投稿的同时重新查一次直播状态(翻页时不重复查)
      _queryLiveRooms(follows);
      loading.value = items.isEmpty;
    } else {
      if (isEnd.value) return;
      _busy = true;
    }

    var fetched = 0;
    var anyNext = false;

    for (var i = 0; i < follows.length; i += _batchSize) {
      final chunk = follows.skip(i).take(_batchSize).toList();
      final results = await Future.wait(
        chunk.map(
          (e) => LocalFeedApi.archives(
            mid: e.mid,
            next: refresh ? null : _cursors[e.mid],
          ),
        ),
      );
      for (var j = 0; j < results.length; j++) {
        final res = results[j];
        if (res case Success(:final response)) {
          final list = response.items;
          if (response.next != null) anyNext = true;
          if (list.isNotEmpty) _cursors[chunk[j].mid] = response.next;
          for (final item in list) {
            if (Pref.hideUpowerExclusiveVideo && item.badge == '充电专属') {
              continue;
            }
            if (LocalBlacklist.blocked(
              mid: item.owner.mid,
              name: item.owner.name,
            )) {
              continue;
            }
            _map[_keyOf(item)] = item;
            fetched++;
          }
        }
      }
    }

    final list = _map.values.toList()
      ..sort((a, b) => (b.pubdate ?? 0).compareTo(a.pubdate ?? 0));
    _updateCounts(list);
    items.assignAll(list);
    loading.value = false;
    _busy = false;

    if (fetched == 0) {
      isEnd.value = true;
    } else {
      // 没有任何一个 UP 还有下一页时视为到底
      isEnd.value = !anyNext;
    }
  }

  /// 下拉刷新 / 进入页面刷新
  Future<void> onRefresh() {
    return queryData(refresh: true);
  }

  void onLoadMore() {
    if (_busy || isEnd.value) return;
    queryData();
  }
}
