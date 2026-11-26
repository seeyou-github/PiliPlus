import 'dart:async';

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
/// 同时把每个 UP 的翻页游标落盘，触底时按游标继续取下一页；
/// 触底翻到保留窗口（[_cacheDays]）之外即视为该 UP 到底。
class LocalFeedController extends GetxController
    with ScrollOrRefreshMixin, RefreshImplMixin {
  /// 每批并发请求的 UP 数量
  static const _batchSize = 5;

  /// 单次查询直播状态的最大 uid 数量
  static const _liveBatchSize = 50;

  /// 刷新时单个 UP 最多续抓的页数
  static const _maxRefreshPages = 5;

  /// 缓存保留天数（最近 1个月）
  static const _cacheDays = 30;

  /// 触底装载的最小间隔，避免列表重建时链式连发
  static const _loadMoreInterval = Duration(seconds: 1);

  @override
  final ScrollController scrollController = ScrollController();

  final items = <VListItemModel>[].obs;
  final loading = true.obs;
  final isEnd = false.obs;

  /// 本次运行期间新增的投稿 key（点击播放即移除，退出应用自动清空）
  final newKeys = <String>{}.obs;

  /// 给动态流读取的普通快照：避免刷新时每条新视频都触发整页 Obx 重建
  final Set<String> newKeysSnapshot = {};

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

  /// 刷新期间被丢弃的刷新请求，结束当前批量请求后补跑
  bool _pendingRefresh = false;

  DateTime _lastLoadMore = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _loadMoreTimer;

  /// 切回动态页时，距上次刷新不足该间隔就只刷新直播状态，避免每次切 tab 都全量请求
  static const _refreshInterval = Duration(minutes: 5);
  DateTime? _lastRefreshAt;

  /// 触底翻页进行中（列表末尾的进度提示据此显示，避免常亮）
  final loadingMore = false.obs;

  /// feedDays 的分组缓存：items 结构每次变化时递增版本号
  int _itemsRev = 0;
  List<LocalFeedDayGroup>? _daysCache;
  int _daysCacheRev = -1;
  int _daysCacheCount = -1;

  /// 离开顶部超过该距离后显示回顶按钮
  static const _backToTopOffset = 400;

  Worker? _followWorker;

  List<LocalFollowItem> get follows => LocalLibrary.follows;

  /// 左侧头像角标：本次新增的投稿数（不随 UP 筛选变化）
  Map<int, int> get updateCounts {
    if (newKeys.isEmpty) return const <int, int>{};
    final counts = <int, int>{};
    for (final item in _map.values) {
      if (!newKeys.contains(LocalFeedCache.keyOf(item))) continue;
      if (!_visible(item)) continue;
      final mid = item.owner.mid;
      if (mid == null) continue;
      counts[mid] = (counts[mid] ?? 0) + 1;
    }
    return counts;
  }

  /// 按天分组后的时间线（items 已按 pubdate 倒序）
  ///
  /// 分组结果按 items 版本缓存，避免每批翻页都重新分组全量条目。
  /// 命中缓存时也会读一次 `items.length`，保持 Obx 对列表的订阅。
  List<LocalFeedDayGroup> get feedDays {
    final count = items.length;
    final cached = _daysCache;
    if (cached != null &&
        _daysCacheRev == _itemsRev &&
        _daysCacheCount == count) {
      return cached;
    }
    final groups = <String, List<VListItemModel>>{};
    final labels = <String, String>{};
    for (final item in items) {
      final key = LocalFeedCache.dayKeyOf(item.pubdate);
      groups.putIfAbsent(key, () => []).add(item);
      labels[key] ??= _dayLabel(item.pubdate);
    }
    final result = [
      for (final entry in groups.entries)
        LocalFeedDayGroup(
          key: entry.key,
          label: labels[entry.key]!,
          items: entry.value,
        ),
    ];
    _daysCache = result;
    _daysCacheRev = _itemsRev;
    _daysCacheCount = count;
    return result;
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
    final pixels = scrollController.position.pixels;
    final show = pixels > _backToTopOffset;
    if (show != showBackToTop.value) showBackToTop.value = show;
    // 回到顶部时把浏览期间推迟的条目一次性放出：此时插入不会造成位移
    if (pixels <= 0 && _hasDeferredItems && !_busy) {
      _hasDeferredItems = false;
      _applyItems();
    }
  }

  /// 视口是否已滚动离开顶部（此时不允许在已有内容上方插入条目，否则会位移）
  bool get _scrolledIntoList =>
      scrollController.hasClients && scrollController.position.pixels > 0;

  /// 滚动浏览期间被推迟的「上方插入」条目，回到顶部后再放出
  bool _hasDeferredItems = false;

  @override
  void onClose() {
    _followWorker?.dispose();
    _loadMoreTimer?.cancel();
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
    final key = LocalFeedCache.keyOf(item);
    newKeys.remove(key);
    if (newKeysSnapshot.remove(key)) {
      // 普通快照不通知 Obx，这里手动刷新一次列表以移除标签
      items.refresh();
    }
  }

  /// 是否展示该投稿（与当前关注/筛选无关的通用过滤）
  bool _visible(VListItemModel item) {
    final mid = item.owner.mid;
    if (mid == null) return false;
    if (Pref.hideUpowerExclusiveVideo && item.badge == '充电专属') {
      return false;
    }
    return !LocalBlacklist.blocked(mid: mid, name: item.owner.name);
  }

  void _applyItems() {
    final follows = this.follows;
    if (follows.isEmpty) {
      items.clear();
      _touchItems();
      return;
    }
    final mids = {for (final e in follows) e.mid};
    final selected = filteredMid.value;
    final list = _map.values.where((item) {
      final mid = item.owner.mid;
      if (mid == null || !mids.contains(mid)) return false;
      if (selected != null && mid != selected) return false;
      return _visible(item);
    }).toList()..sort((a, b) => (b.pubdate ?? 0).compareTo(a.pubdate ?? 0));
    items.assignAll(list);
    _touchItems();
  }

  /// items 结构变化后让 [feedDays] 的分组缓存失效
  void _touchItems() => _itemsRev++;

  /// 翻页 / 刷新时只过滤并合并新投稿，避免每次都对全量缓存重新过滤 / 排序
  ///
  /// 已存在的条目（同 key）就地替换，保证播放量、角标等字段能随刷新更新。
  void _appendItems(
    List<VListItemModel> fresh,
    List<LocalFollowItem> follows,
  ) {
    if (fresh.isEmpty) return;
    final mids = {for (final e in follows) e.mid};
    final selected = filteredMid.value;
    final current = items.toList();
    // 已经滚离顶部时只允许「末尾追加」：把条目录入到已有内容上方会让整段内容
    // 下移，表现为页面自己往上跳（触底加载时较早的分组被补入新行尤其明显）
    final tailPubdate = _scrolledIntoList && current.isNotEmpty
        ? (current.last.pubdate ?? 0)
        : null;
    final indexOf = <String, int>{
      for (var i = 0; i < current.length; i++)
        LocalFeedCache.keyOf(current[i]): i,
    };
    var replaced = false;
    final incoming = <VListItemModel>[];
    for (final item in fresh) {
      final mid = item.owner.mid;
      if (mid == null || !mids.contains(mid)) continue;
      if (selected != null && mid != selected) continue;
      if (!_visible(item)) continue;
      if (tailPubdate != null && (item.pubdate ?? 0) > tailPubdate) {
        // 先不显示，等回到顶部再统一放出（避免浏览中列表整体位移）
        _hasDeferredItems = true;
        continue;
      }
      final key = LocalFeedCache.keyOf(item);
      final at = indexOf[key];
      if (at != null) {
        if (at >= 0 && !identical(current[at], item)) {
          current[at] = item;
          replaced = true;
        }
        continue;
      }
      indexOf[key] = -1;
      incoming.add(item);
    }
    if (incoming.isEmpty) {
      if (replaced) {
        items.assignAll(current);
        _touchItems();
      }
      return;
    }
    incoming.sort((a, b) => (b.pubdate ?? 0).compareTo(a.pubdate ?? 0));

    // 与现有已排序列表做一次线性归并
    final merged = <VListItemModel>[];
    var i = 0;
    var j = 0;
    while (i < current.length && j < incoming.length) {
      if ((current[i].pubdate ?? 0) >= (incoming[j].pubdate ?? 0)) {
        merged.add(current[i++]);
      } else {
        merged.add(incoming[j++]);
      }
    }
    while (i < current.length) {
      merged.add(current[i++]);
    }
    while (j < incoming.length) {
      merged.add(incoming[j++]);
    }
    items.assignAll(merged);
    _touchItems();
  }

  String _dayLabel(int? pubdate) {
    final day = LocalFeedCache.dayOf(pubdate);
    if (day == null) return '更早';
    final now = DateTime.now();
    // 用 UTC 零点做差，避免夏令时导致天数少算一天
    final diff = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime.utc(day.year, day.month, day.day)).inDays;
    if (diff <= 0) return '今天';
    if (diff == 1) return '昨天';
    // 两天前 … 七天前
    if (diff <= 7) return '$diff天前';
    // 八天前开始显示日期
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
    if (_busy) {
      // 关注变化等触发的刷新不能丢，等当前批次结束后补跑
      if (refresh) _pendingRefresh = true;
      return;
    }
    final follows = this.follows;
    if (follows.isEmpty) {
      _map.clear();
      items.clear();
      _touchItems();
      newKeys.clear();
      newKeysSnapshot.clear();
      updatedMids.clear();
      liveRooms.clear();
      loading.value = false;
      await LocalFeedCache.clear();
      isEnd.value = true;
      return;
    }

    _busy = true;
    if (!refresh) loadingMore.value = true;
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
        final fresh = await _fetchLatest(follows);
        // 增量合并新抓到的投稿，避免再对全量缓存做一次过滤 + 排序
        _appendItems(fresh, follows);
        // isEnd 只表示网络是否到底，本地更早的缓存由 fillViewport 放出
        isEnd.value = follows.every((e) => LocalFeedCache.cursorOf(e.mid) == -1);
      } else {
        final fresh = await _fetchMore(follows);
        _appendItems(fresh, follows);
      }
      unawaited(LocalFeedCache.flush());
    } finally {
      loading.value = false;
      loadingMore.value = false;
      _busy = false;
      if (refresh) _lastRefreshAt = DateTime.now();
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(queryData(refresh: true));
      }
    }
  }

  /// 刷新：每个 UP 从最新一页开始，翻到与旧内容重叠为止
  ///
  /// 返回本次新抓到的投稿，由调用方增量合并到列表中。
  Future<List<VListItemModel>> _fetchLatest(
    List<LocalFollowItem> follows,
  ) async {
    final cutoff = LocalFeedCache.cutoffOf(_cacheDays);
    // 批量收集新视频标记，避免每新增一条都触发一次整页重建
    final newKeysBatch = <String>{};
    final updatedMidsBatch = <int>{};
    final merged = <VListItemModel>[];
    for (var i = 0; i < follows.length; i += _batchSize) {
      final chunk = follows.skip(i).take(_batchSize).toList();
      final results = await Future.wait(
        chunk.map(
          (e) => _fetchUpLatest(e.mid, newKeysBatch, updatedMidsBatch),
        ),
      );
      for (final list in results) {
        // 超过保留窗口的投稿不展示也不落盘
        final fresh = [
          for (final item in list)
            if (!LocalFeedCache.expired(item.pubdate, cutoff)) item,
        ];
        if (fresh.isEmpty) continue;
        LocalFeedCache.merge(fresh);
        merged.addAll(fresh);
        for (final item in fresh) {
          _map[LocalFeedCache.keyOf(item)] = item;
        }
      }
      _flushNewItems(newKeysBatch, updatedMidsBatch);
    }
    return merged;
  }

  /// 一批 UP 抓取完成后一次性提交通知，减少动态页整页重建次数
  void _flushNewItems(Set<String> newKeysBatch, Set<int> updatedMidsBatch) {
    if (newKeysBatch.isNotEmpty) {
      newKeysSnapshot.addAll(newKeysBatch);
      newKeys.addAll(newKeysBatch);
      newKeysBatch.clear();
    }
    if (updatedMidsBatch.isNotEmpty) {
      updatedMids.addAll(updatedMidsBatch);
      updatedMidsBatch.clear();
    }
  }

  Future<List<VListItemModel>> _fetchUpLatest(
    int mid,
    Set<String> newKeysBatch,
    Set<int> updatedMidsBatch,
  ) async {
    final oldBaseline = LocalFeedCache.baselineOf(mid);
    final fetched = <VListItemModel>[];
    int? aid;
    int? next;
    var first = true;
    var success = false;
    var reachedBaseline = false;
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
      if (!list.any((e) => (e.pubdate ?? 0) > oldBaseline)) {
        reachedBaseline = true;
        break;
      }
      aid = next;
      first = false;
    }

    if (oldBaseline != null) {
      for (final item in fetched) {
        if ((item.pubdate ?? 0) > oldBaseline) {
          newKeysBatch.add(LocalFeedCache.keyOf(item));
          updatedMidsBatch.add(mid);
        }
      }
    }
    // 请求一页都没成功时不要写基线/游标，避免把没取到的内容当作已同步
    if (!success) return fetched;
    if (maxPubdate > 0) LocalFeedCache.setBaseline(mid, maxPubdate);
    if (next == null) {
      // 该 UP 的投稿已全部取完
      LocalFeedCache.setCursor(mid, -1);
    } else if (!reachedBaseline || LocalFeedCache.cursorOf(mid) == null) {
      // 没追平缓存（首次抓取 / 命中续抓页数上限 / 中途失败）：
      // 游标必须停在已抓取区间的末尾，否则中间这段投稿永远取不到。
      // 已追平但还没有游标（旧数据 / 上次全都失败）时也补写一次，
      // 否则触底翻页会一直跳过这个 UP。
      LocalFeedCache.setCursor(mid, next);
    }
    // 已追平缓存时保持原游标（含 -1），下次刷新不会重复回扫历史
    return fetched;
  }

  /// 触底：每个 UP 按持久化游标继续取下一页，翻到保留窗口外即视为到底
  Future<List<VListItemModel>> _fetchMore(List<LocalFollowItem> follows) async {
    // 游标为 null 表示还没建立续页位置：`next: null` 请求拿到的是「最新一页」，
    // 在触底时抓最新一页只会把新内容插到列表上方，同时白跑请求。
    // 这类 UP 交给刷新（_fetchUpLatest）去建立游标。
    final targets = follows.where((e) {
      final cursor = LocalFeedCache.cursorOf(e.mid);
      return cursor != null && cursor != -1;
    }).toList();
    if (targets.isEmpty) {
      isEnd.value = true;
      return const [];
    }

    final cutoff = LocalFeedCache.cutoffOf(_cacheDays);
    final fetched = <VListItemModel>[];
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
          final items = response.items;
          final fresh = [
            for (final item in items)
              if (!LocalFeedCache.expired(item.pubdate, cutoff)) item,
          ];
          if (fresh.isNotEmpty) {
            LocalFeedCache.merge(fresh);
            fetched.addAll(fresh);
            for (final item in fresh) {
              _map[LocalFeedCache.keyOf(item)] = item;
            }
          }
          // 本页已出现超期投稿，说明再往前只有更旧的，直接结束该 UP
          final reachedRetention = fresh.length < items.length;
          final next = response.next;
          LocalFeedCache.setCursor(
            result.mid,
            reachedRetention ? -1 : (next ?? -1),
          );
          if (!reachedRetention && next != null) anyNext = true;
        } else {
          // 失败保留原游标，下次触底重试
          anyNext = true;
        }
      }
    }
    isEnd.value = !anyNext;
    return fetched;
  }

  /// 内容不足一屏 / 用户滑到底时补内容
  ///
  /// - 用户主动滑到底且网络还有页：正常网络翻页（异步）
  /// - 其余情况只放出更早的本地缓存（同步，不发网络请求）
  ///
  /// 返回 true 表示本次同步加入了内容，调用方可以再检查一次视口。
  bool fillViewport({bool byUser = false}) {
    if (_busy) return false;
    if (byUser && !isEnd.value) {
      onLoadMore();
      return false;
    }
    if (!LocalFeedCache.hasPending) return false;
    final before = items.length;
    _releaseOlderCache();
    return items.length > before;
  }

  /// 按天桶放出更早的本地缓存（每次一桶）
  ///
  /// 只做末尾方向的增量合并，不重排整张列表：重新过滤 + 排序会把其它来源的
  /// 条目录入上方，导致正在浏览的视口整体下移。
  void _releaseOlderCache() {
    if (!LocalFeedCache.hasPending) return;
    final older = LocalFeedCache.loadNextBucket();
    if (older.isEmpty) return;
    for (final item in older) {
      _map[LocalFeedCache.keyOf(item)] = item;
    }
    _appendItems(older, follows);
  }

  /// 切回动态页时调用：数据还新就只刷新直播状态，避免每次切 tab 都全量请求
  Future<void> refreshIfStale() {
    final last = _lastRefreshAt;
    if (last != null && DateTime.now().difference(last) < _refreshInterval) {
      // 直播状态开销小（每 50 个 UP 一次请求），不受新鲜度限制
      final follows = this.follows;
      if (follows.isNotEmpty) unawaited(_queryLiveRooms(follows));
      return Future<void>.value();
    }
    return queryData(refresh: true);
  }

  /// 下拉刷新 / 进入页面刷新
  Future<void> onRefresh() => queryData(refresh: true);

  void onLoadMore() {
    if (_busy || isEnd.value) return;
    final now = DateTime.now();
    final elapsed = now.difference(_lastLoadMore);
    if (elapsed < _loadMoreInterval) {
      // 列表重建会反复触发，用一次性定时器补上最后一次，避免链式连发
      _loadMoreTimer ??= Timer(_loadMoreInterval - elapsed, () {
        _loadMoreTimer = null;
        onLoadMore();
      });
      return;
    }
    _lastLoadMore = now;
    queryData();
  }
}
