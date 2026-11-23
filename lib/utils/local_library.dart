import 'package:PiliPlus/models/local/local_fav_item.dart';
import 'package:PiliPlus/models/local/local_follow_item.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';

/// 本地关注 / 本地收藏的统一读写入口
///
/// 设计要点：
/// - 只读写独立的 `localFollow` / `localFav` 两个 box，与在线数据完全隔离；
/// - 内存中维护 `Map` 作为索引，UI 通过 [followCount] / [favCount] 响应式刷新；
/// - 登录态下这些数据仍然保留但不再展示（由调用方用 [isGuest] 判断）。
class LocalLibrary {
  LocalLibrary._();

  static bool _loaded = false;

  static final Map<int, LocalFollowItem> _follows = {};
  static final Map<String, LocalFavItem> _favs = {};

  /// 本地关注数量
  static final followCount = 0.obs;

  /// 本地收藏数量
  static final favCount = 0.obs;

  /// 当前是否为「未登录」状态，只有未登录才使用本地数据
  static bool get isGuest => !Accounts.main.isLogin;

  static Box<dynamic> get _followBox => GStorage.localFollow;
  static Box<dynamic> get _favBox => GStorage.localFav;

  /// 预加载（应用启动时调用，保证计数正确）
  static void ensureLoaded() => _ensureLoaded();

  static void _ensureLoaded() {
    if (_loaded) return;
    _loaded = true;
    for (final entry in _followBox.toMap().entries) {
      final item = LocalFollowItem.fromMap(entry.key, entry.value);
      if (item.mid > 0) _follows[item.mid] = item;
    }
    for (final entry in _favBox.toMap().entries) {
      final item = LocalFavItem.fromMap(entry.key, entry.value);
      if (item.oid > 0) _favs[item.key] = item;
    }
    followCount.value = _follows.length;
    favCount.value = _favs.length;
  }

  // ---------------- 本地关注 ----------------

  /// 全部本地关注（按关注时间倒序）
  static List<LocalFollowItem> get follows {
    _ensureLoaded();
    final list = _follows.values.toList()
      ..sort((a, b) => b.addTime.compareTo(a.addTime));
    return list;
  }

  static LocalFollowItem? followItemOf(int? mid) {
    if (mid == null) return null;
    _ensureLoaded();
    return _follows[mid];
  }

  static bool isFollowing(int? mid) => followItemOf(mid) != null;

  /// 新增或更新本地关注，返回是否为新增
  static bool follow(LocalFollowItem item) {
    _ensureLoaded();
    final exists = _follows.containsKey(item.mid);
    _follows[item.mid] = item;
    _followBox.put(item.mid, item.toMap());
    followCount.value = _follows.length;
    return !exists;
  }

  static bool unfollow(int mid) {
    _ensureLoaded();
    if (_follows.remove(mid) == null) return false;
    _followBox.delete(mid);
    followCount.value = _follows.length;
    return true;
  }

  static void clearFollows() {
    _ensureLoaded();
    _follows.clear();
    _followBox.clear();
    followCount.value = 0;
  }

  // ---------------- 本地收藏 ----------------

  /// 全部本地收藏（按收藏时间倒序）
  static List<LocalFavItem> get favs {
    _ensureLoaded();
    final list = _favs.values.toList()
      ..sort((a, b) => b.addTime.compareTo(a.addTime));
    return list;
  }

  static List<LocalFavItem> favsOf(LocalFavType type) =>
      favs.where((e) => e.type == type).toList();

  /// 各类型的收藏数量
  static Map<LocalFavType, int> get favTypeCount {
    _ensureLoaded();
    final map = <LocalFavType, int>{};
    for (final item in _favs.values) {
      map[item.type] = (map[item.type] ?? 0) + 1;
    }
    return map;
  }

  static bool isFaved(LocalFavType type, int? oid) {
    if (oid == null || oid == 0) return false;
    _ensureLoaded();
    return _favs.containsKey('${type.name}:$oid');
  }

  /// 新增本地收藏，返回是否为新增
  static bool addFav(LocalFavItem item) {
    _ensureLoaded();
    final exists = _favs.containsKey(item.key);
    _favs[item.key] = item;
    _favBox.put(item.key, item.toMap());
    favCount.value = _favs.length;
    return !exists;
  }

  static bool removeFav(LocalFavType type, int oid) {
    _ensureLoaded();
    final key = '${type.name}:$oid';
    if (_favs.remove(key) == null) return false;
    _favBox.delete(key);
    favCount.value = _favs.length;
    return true;
  }

  static void removeFavItem(LocalFavItem item) =>
      removeFav(item.type, item.oid);

  static void clearFavs([LocalFavType? type]) {
    _ensureLoaded();
    if (type == null) {
      _favs.clear();
      _favBox.clear();
    } else {
      _favs.removeWhere((_, v) => v.type == type);
      _favBox.keys
          .where((k) => '$k'.startsWith('${type.name}:'))
          .toList()
          .forEach(_favBox.delete);
    }
    favCount.value = _favs.length;
  }

  // ---------------- 导入 / 导出 ----------------

  /// 导出结构：{ follows: [...], favs: [...] }
  static Map<String, dynamic> exportJson() {
    _ensureLoaded();
    return {
      'follows': [for (final e in follows) e.toMap()],
      'favs': [for (final e in favs) e.toMap()],
    };
  }

  /// 导入（覆盖式），兼容只含其中一项的结构
  static Future<void> importJson(Object? json, {bool merge = false}) async {
    _ensureLoaded();
    if (json is! Map) return;
    final follows = json['follows'];
    final favs = json['favs'];

    if (!merge) {
      _follows.clear();
      _favs.clear();
      await _followBox.clear();
      await _favBox.clear();
    }

    if (follows is List) {
      for (final e in follows) {
        final item = LocalFollowItem.fromMap(null, e);
        if (item.mid > 0) {
          _follows[item.mid] = item;
          await _followBox.put(item.mid, item.toMap());
        }
      }
    }
    if (favs is List) {
      for (final e in favs) {
        final item = LocalFavItem.fromMap(null, e);
        if (item.oid > 0) {
          _favs[item.key] = item;
          await _favBox.put(item.key, item.toMap());
        }
      }
    }
    followCount.value = _follows.length;
    favCount.value = _favs.length;
  }
}
