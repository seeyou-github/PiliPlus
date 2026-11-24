import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/member.dart';
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
/// 只拉取本地关注 UP 的投稿（`searchArchive`，按发布时间倒序），
/// 多 UP 结果合并去重后按 `pubdate` 倒序展示，逻辑参考 PipePipe 的本地 feed：
/// 逐订阅抓取 → 合并 → 排序 → 缓存。
class LocalFeedController extends GetxController
    with ScrollOrRefreshMixin, RefreshImplMixin {
  /// 每批并发请求的 UP 数量
  static const _batchSize = 5;

  /// 每个 UP 每页拉取数量
  static const _ps = 30;

  /// 缓存有效期
  static const _cacheTtl = Duration(minutes: 5);

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
  int _page = 1;
  bool _initialized = false;

  final Map<String, VListItemModel> _map = {};
  final Map<int, int> _lastPubdate = {};

  static DateTime? _cacheTime;
  static List<VListItemModel>? _cache;

  Worker? _followWorker;

  List<LocalFollowItem> get follows => LocalLibrary.follows;

  @override
  void onInit() {
    super.onInit();
    // 首次关注后立即拉取投稿，避免动态页停留在「还没有本地关注」
    _followWorker = ever(LocalLibrary.followCount, (_) => onRefresh());
    queryData(refresh: true);
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
      for (var i = 0; i < follows.length; i += _batchSize) {
        final chunk = follows.skip(i).take(_batchSize).toList();
        final results = await Future.wait(
          chunk.map((e) => MemberHttp.memberInfo(mid: e.mid)),
        );
        for (var j = 0; j < results.length; j++) {
          final res = results[j];
          if (res case Success(:final response)) {
            final room = response.liveRoom;
            if (room?.liveStatus == 1 && room?.roomId != null) {
              rooms[chunk[j].mid] = room!;
            }
          }
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

  /// [refresh] 为 true 时回到第一页，并优先使用 5 分钟内的缓存
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

    _queryLiveRooms(follows);

    if (refresh) {
      _page = 1;
      isEnd.value = false;
      _busy = true;
      if (_cache != null &&
          _cacheTime != null &&
          DateTime.now().difference(_cacheTime!) < _cacheTtl) {
        _map
          ..clear()
          ..addEntries(_cache!.map((e) => MapEntry(_keyOf(e), e)));
        items.assignAll(_cache!);
        loading.value = false;
        _busy = false;
        return;
      }
      loading.value = items.isEmpty;
    } else {
      if (isEnd.value) return;
      _busy = true;
    }

    final page = _page;
    var fetched = 0;
    var anyFull = false;

    for (var i = 0; i < follows.length; i += _batchSize) {
      final chunk = follows.skip(i).take(_batchSize);
      final results = await Future.wait(
        chunk.map(
          (e) => MemberHttp.searchArchive(mid: e.mid, pn: page, ps: _ps),
        ),
      );
      for (final res in results) {
        if (res case Success(:final response)) {
          final list = response.list?.vlist;
          if (list == null || list.isEmpty) continue;
          if (list.length >= _ps) anyFull = true;
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
    _cache = list;
    _cacheTime = DateTime.now();

    if (fetched == 0) {
      isEnd.value = true;
    } else {
      // 没有任何一个 UP 还有下一页时视为到底
      isEnd.value = !anyFull;
      _page++;
    }
  }

  /// 下拉刷新（忽略缓存）
  Future<void> onRefresh() {
    _cache = null;
    _cacheTime = null;
    return queryData(refresh: true);
  }

  void onLoadMore() {
    if (_busy || isEnd.value) return;
    queryData();
  }
}
