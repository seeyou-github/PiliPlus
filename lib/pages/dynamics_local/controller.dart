import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/member.dart';
import 'package:PiliPlus/models/local/local_follow_item.dart';
import 'package:PiliPlus/models_new/member/search_archive/vlist.dart';
import 'package:PiliPlus/utils/local_blacklist.dart';
import 'package:PiliPlus/utils/local_library.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:get/get.dart';

/// 本地关注投稿流（未登录时使用）
///
/// 只拉取本地关注 UP 的投稿（`searchArchive`，按发布时间倒序），
/// 多 UP 结果合并去重后按 `pubdate` 倒序展示，逻辑参考 PipePipe 的本地 feed：
/// 逐订阅抓取 → 合并 → 排序 → 缓存。
class LocalFeedController extends GetxController {
  /// 每批并发请求的 UP 数量
  static const _batchSize = 5;

  /// 每个 UP 每页拉取数量
  static const _ps = 30;

  /// 缓存有效期
  static const _cacheTtl = Duration(minutes: 5);

  final items = <VListItemModel>[].obs;
  final loading = true.obs;
  final isEnd = false.obs;

  bool _busy = false;
  int _page = 1;

  final Map<String, VListItemModel> _map = {};

  static DateTime? _cacheTime;
  static List<VListItemModel>? _cache;

  List<LocalFollowItem> get follows => LocalLibrary.follows;

  @override
  void onInit() {
    super.onInit();
    queryData(refresh: true);
  }

  String _keyOf(VListItemModel item) =>
      item.bvid ?? (item.aid != null ? 'av${item.aid}' : item.title);

  /// [refresh] 为 true 时回到第一页，并优先使用 5 分钟内的缓存
  Future<void> queryData({bool refresh = false}) async {
    if (_busy) return;
    final follows = this.follows;
    if (follows.isEmpty) {
      _map.clear();
      items.clear();
      loading.value = false;
      isEnd.value = true;
      return;
    }

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
