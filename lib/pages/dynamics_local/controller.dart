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
import 'package:PiliPlus/utils/local_feed_cache.dart';
import 'package:PiliPlus/utils/local_library.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/widgets.dart' show ScrollController;
import 'package:get/get.dart';

/// 按天分组的时间线分组
class LocalFeedDayGroup {
  const LocalFeedDayGroup({
    required this.key,
    required this.label,
    required this.items,
  });

  final String key;
  final String label;
  final List<VListItemModel> items;
}

/// 本地关注投稿流（未登录时使用）
///
/// 缓存优先：进入页面先展示本地缓存，再在线抓取新增投稿并标记「新视频」，
/// 同时把每个 UP 的翻页游标落盘，触底时按游标继续取下一页。
class LocalFeedController extends GetxController
    with ScrollOrRefreshMixin, RefreshImplMixin {
  /// 每批并发请求的 UP 数量
  static const _batchSize = 5;

  /// 单次查询直播状态的最大 uid 数量
  static const _liveBatchSize = 50;

  /// 刷新时单个 UP 最多续抓的页数
  static const _maxRefreshPages = 5;

  /// 缓存保留天数
  static const _cacheDays = 30;

  @override
  final ScrollController scrollController = ScrollController();

  final items = <VListItemModel>[].obs;
  final loading = true.obs;
  final isEnd = false.obs;

  /// 本次运行期间新增的投稿 key（点击播放即移除，退出应用自动清空）
  final newKeys = <String>{}.obs;

  /// 本次运行期间有新增投稿的 UP（关注分组置顶用，不随已读移除）
  final updatedMids = <int>{}.obs;

  /// 本地关注中正在直播的 UP（mid -> 直播间）
  final liveRooms = <int, LiveRoom>{}.obs;

  /// 当前筛选的 UP（null 表示显示全部）
  final filteredMid = RxnInt();

  /// 滚动离开顶部时显示「回到顶部」按钮
  final showBackToTop = false.obs;

  final Map<String, VListItemModel> _map = {};
  bool _busy = false;

  /// 离开顶部超过该距离后显示回顶按钮
  static const _backToTopOffset = 400;

  Worker? _followWorker;

  List<LocalFollowItem> get follows => LocalLibrary.follows;

  /// 左侧头像角标：本次新增且当前展示中的投稿数
  Map<int, int> get updateCounts {
    if (newKeys.isEmpty) return const <int, int>{};
    final counts = <int, int>{};
    for (final item in items) {
      if (!newKeys.contains(LocalFeedCache.keyOf(item))) continue;
      final mid = item.owner.mid;
      if (mid == null) continue;
      counts[mid] = (counts[mid] ?? 0) + 1;
    }
    return counts;
  }

  /// 按天分组后的时间线（items 已按 pubdate 倒序）
  List<LocalFeedDayGroup> get feedDays {
    final groups = <String, List<VListItemModel>>{};
    final labels = <String, String>{};
    for (final item in items) {
      final key = LocalFeedCache.dayKeyOf(item.pubdate);
      groups.putIfAbsent(key, () => []).add(item);
      labels[key] ??= _dayLabel(item.pubdate);
    }
    return [
      for (final entry in groups.entries)
        LocalFeedDayGroup(
          key: entry.key,
          label: labels[entry.key]!,
          items: entry.value,
        ),
    ];
  }

  @override
  void onInit() {
    super.onInit();
    LocalFeedCache.ensureLoaded();
    _map.addAll(LocalFeedCache.itemsMap);
    _applyItems();
    loading.value = items.isEmpty && follows.isNotEmpty;
    // 首次关注后立即拉取投稿，避免动态页停留在「还没有本地关注」
    _followWorker = ever(LocalLibrary.followCount, (_) {
      final selected = filteredMid.value;
      if (selected != null && !LocalLibrary.isFollowing(selected)) {
        filteredMid.value = null;
      }
      onRefresh();
    });
    // 进入本地关注模式即刷新投稿，同时刷新 UP 的直播状态
    onRefresh();
    scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final show = scrollController.position.pixels > _backToTopOffset;
    if (show != showBackToTop.value) showBackToTop.value = show;
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

  /// 参考主页按钮：离开顶部时回到顶部，已在顶部时刷新投稿与直播状态
  void backToTopOrRefresh() {
    if (scrollController.hasClients && scrollController.position.pixels > 0) {
      animateToTop();
    } else {
      showRefresh();
    }
  }

  /// 点击左侧关注 UP 头像：筛选/取消筛选该 UP 的投稿
  void toggleFilter(int mid) {
    filteredMid.value = filteredMid.value == mid ? null : mid;
    _applyItems();
    if (scrollController.hasClients) animateToTop();
  }

  /// 播放后清除该条目的「新视频」标签
  void markNewRead(VListItemModel item) {
    newKeys.remove(LocalFeedCache.keyOf(item));
  }

  void _applyItems() {
    final follows = this.follows;
    if (follows.isEmpty) {
      items.clear();
      return;
    }
    final mids = {for (final e in follows) e.mid};
    final selected = filteredMid.value;
    final list = _map.values.where((item) {
      final mid = item.owner.mid;
      if (mid == null || !mids.contains(mid)) return false;
      if (selected != null && mid != selected) return false;
      if (Pref.hideUpowerExclusiveVideo && item.badge == '充电专属') {
        return false;
      }
      if (LocalBlacklist.blocked(mid: mid, name: item.owner.name)) {
        return false;
      }
      return true;
    }).toList()..sort((a, b) => (b.pubdate ?? 0).compareTo(a.pubdate ?? 0));
    items.assignAll(list);
  }

  String _dayLabel(int? pubdate) {
    final day = LocalFeedCache.dayOf(pubdate);
    if (day == null) return '更早';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    if (day.year == now.year) return '${day.month}月${day.day}日';
    return '${day.year}年${day.month}月${day.day}日';
  }

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

  /// [refresh] 为 true 时回到最新一页重新抓取，并顺带刷新直播状态
  Future<void> queryData({bool refresh = false}) async {
    if (_busy) return;
    final follows = this.follows;
    if (follows.isEmpty) {
      _map.clear();
      items.clear();
      newKeys.clear();
      updatedMids.clear();
      liveRooms.clear();
      loading.value = false;
      isEnd.value = true;
      await LocalFeedCache.clear();
      return;
    }

    _busy = true;
    try {
      if (refresh) {
        LocalFeedCache.prune(
          followedMids: {for (final e in follows) e.mid},
          keepDays: _cacheDays,
        );
        _map
          ..clear()
          ..addAll(LocalFeedCache.itemsMap);
        _applyItems();
        loading.value = _map.isEmpty;
        isEnd.value = false;
        // 刷新投稿的同时重新查一次直播状态（翻页时不重复查）
        _queryLiveRooms(follows);
        await _fetchLatest(follows);
        isEnd.value = follows.every(
          (e) => LocalFeedCache.cursorOf(e.mid) == -1,
        );
      } else {
        await _fetchMore(follows);
      }
      _applyItems();
      await LocalFeedCache.flush(full: refresh);
    } finally {
      loading.value = false;
      _busy = false;
    }
  }

  /// 刷新：每个 UP 从最新一页开始，翻到与旧内容重叠为止
  Future<void> _fetchLatest(List<LocalFollowItem> follows) async {
    for (var i = 0; i < follows.length; i += _batchSize) {
      final chunk = follows.skip(i).take(_batchSize).toList();
      final results = await Future.wait(
        chunk.map((e) => _fetchUpLatest(e.mid)),
      );
      for (final list in results) {
        if (list.isEmpty) continue;
        LocalFeedCache.merge(list);
        for (final item in list) {
          _map[LocalFeedCache.keyOf(item)] = item;
        }
      }
    }
  }

  Future<List<VListItemModel>> _fetchUpLatest(int mid) async {
    final oldBaseline = LocalFeedCache.baselineOf(mid);
    final oldCursor = LocalFeedCache.cursorOf(mid);
    final fetched = <VListItemModel>[];
    int? aid;
    int? next;
    var first = true;
    var success = false;
    var maxPubdate = 0;

    for (var page = 0; page < _maxRefreshPages; page++) {
      final res = await LocalFeedApi.archives(
        mid: mid,
        next: first ? null : aid,
      );
      if (res is! Success<LocalFeedArchiveResult>) break;
      success = true;
      final response = res.response;
      final list = response.items;
      fetched.addAll(list);
      next = response.next;
      for (final item in list) {
        final pubdate = item.pubdate ?? 0;
        if (pubdate > maxPubdate) maxPubdate = pubdate;
      }
      if (next == null) break;
      // 首次抓取没有历史基线，只取一页
      if (oldBaseline == null) break;
      // 本页已没有比上次更晚的投稿，说明已追平缓存
      if (!list.any((e) => (e.pubdate ?? 0) > oldBaseline)) break;
      aid = next;
      first = false;
    }

    if (oldBaseline != null) {
      for (final item in fetched) {
        if ((item.pubdate ?? 0) > oldBaseline) {
          newKeys.add(LocalFeedCache.keyOf(item));
          updatedMids.add(mid);
        }
      }
    }
    // 请求全部失败时不要写游标，避免把未取到的分页误标为已取完
    if (!success) return fetched;
    if (maxPubdate > 0) LocalFeedCache.setBaseline(mid, maxPubdate);
    // 深层游标只在从未建立时初始化，避免刷新把已翻到的位置重置
    if (next == null) {
      LocalFeedCache.setCursor(mid, -1);
    } else if (oldCursor == null || oldCursor == -1) {
      LocalFeedCache.setCursor(mid, next);
    }
    return fetched;
  }

  /// 触底：每个 UP 按持久化游标继续取下一页
  Future<void> _fetchMore(List<LocalFollowItem> follows) async {
    final targets = follows
        .where((e) => LocalFeedCache.cursorOf(e.mid) != -1)
        .toList();
    if (targets.isEmpty) {
      isEnd.value = true;
      return;
    }

    var anyNext = false;
    for (var i = 0; i < targets.length; i += _batchSize) {
      final chunk = targets.skip(i).take(_batchSize).toList();
      final results = await Future.wait(
        chunk.map((e) async {
          final res = await LocalFeedApi.archives(
            mid: e.mid,
            next: LocalFeedCache.cursorOf(e.mid),
          );
          return (mid: e.mid, res: res);
        }),
      );
      for (final result in results) {
        final res = result.res;
        if (res case Success(:final response)) {
          if (response.items.isNotEmpty) {
            LocalFeedCache.merge(response.items);
            for (final item in response.items) {
              _map[LocalFeedCache.keyOf(item)] = item;
            }
          }
          final next = response.next;
          LocalFeedCache.setCursor(result.mid, next ?? -1);
          if (next != null) anyNext = true;
        } else {
          // 失败保留原游标，下次触底重试
          anyNext = true;
        }
      }
    }
    isEnd.value = !anyNext;
  }

  /// 下拉刷新 / 进入页面刷新
  Future<void> onRefresh() => queryData(refresh: true);

  void onLoadMore() {
    if (_busy || isEnd.value) return;
    queryData();
  }
}
