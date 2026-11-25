import 'package:PiliPlus/models_new/member/search_archive/vlist.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:hive_ce/hive.dart';

/// 本地关注投稿的落盘缓存
///
/// 存储结构（box: localFeed）：
/// - `d:yyyy-MM-dd` -> 当天的投稿列表（按天分桶，便于裁剪）
/// - `cursors`      -> { mid: 下一页 aid 游标 }，-1 表示该 UP 已取完
/// - `baseline`     -> { mid: 历史最大 pubdate }，用于识别「新视频」
abstract final class LocalFeedCache {
  static const _dayPrefix = 'd:';
  static const _cursorsKey = 'cursors';
  static const _baselineKey = 'baseline';
  static const _unknownDay = 'unknown';

  static bool _loaded = false;
  static final Map<String, VListItemModel> _items = {};
  static final Map<int, int> _cursors = {};
  static final Map<int, int> _baselines = {};
  static final Set<String> _dirtyDays = {};

  /// 启动时先解最近这些天的桶，其余留到滚动时按需加载，
  /// 避免冷启动时把 90 天的数据一次性反序列化成对象。
  static const int _initialDays = 7;

  /// 尚未加载的日期桶（从新到旧）
  static final List<String> _pendingBuckets = [];

  static Box<dynamic> get _box => GStorage.localFeed;

  static Map<String, VListItemModel> get itemsMap => _items;

  static String keyOf(VListItemModel item) =>
      item.bvid ?? (item.aid != null ? 'av${item.aid}' : item.title);

  static DateTime? dayOf(int? pubdate) {
    if (pubdate == null || pubdate <= 0) return null;
    final date = DateTime.fromMillisecondsSinceEpoch(pubdate * 1000);
    return DateTime(date.year, date.month, date.day);
  }

  static String dayKeyOf(int? pubdate) {
    final day = dayOf(pubdate);
    if (day == null) return _unknownDay;
    final month = day.month.toString().padLeft(2, '0');
    final date = day.day.toString().padLeft(2, '0');
    return '${day.year}-$month-$date';
  }

  static void ensureLoaded() {
    if (_loaded) return;
    _loaded = true;
    final buckets = <String, List>{};
    for (final entry in _box.toMap().entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String) continue;
      if (key.startsWith(_dayPrefix)) {
        // 无法按天归档的旧数据不再加载，交由 prune/flush 清掉
        if (key == '$_dayPrefix$_unknownDay') continue;
        if (value is! List) continue;
        buckets[key] = value;
      } else if (key == _cursorsKey && value is Map) {
        value.forEach((k, v) {
          final mid = int.tryParse('$k');
          final cursor = v is num ? v.toInt() : int.tryParse('$v');
          if (mid != null && cursor != null) _cursors[mid] = cursor;
        });
      } else if (key == _baselineKey && value is Map) {
        value.forEach((k, v) {
          final mid = int.tryParse('$k');
          final pubdate = v is num ? v.toInt() : int.tryParse('$v');
          if (mid != null && pubdate != null) _baselines[mid] = pubdate;
        });
      }
    }
    // 日期桶名可直接按字符串比较大小，从新到旧只解前 `_initialDays` 天
    final days = buckets.keys.toList()..sort((a, b) => b.compareTo(a));
    for (var i = 0; i < days.length; i++) {
      if (i < _initialDays) {
        _loadBucket(buckets[days[i]]);
      } else {
        _pendingBuckets.add(days[i]);
      }
    }
  }

  static void _loadBucket(List? raw) {
    if (raw == null) return;
    for (final entry in raw) {
      final item = _fromMap(entry);
      if (item == null) continue;
      _items[keyOf(item)] = item;
    }
  }

  /// 是否还有更早的日期桶没加载
  static bool get hasPending => _pendingBuckets.isNotEmpty;

  /// 放出下一个（次新）未加载的日期桶，返回新加入内存的条目
  static List<VListItemModel> loadNextBucket() {
    if (_pendingBuckets.isEmpty) return const [];
    final key = _pendingBuckets.removeAt(0);
    final raw = _box.get(key);
    final added = <VListItemModel>[];
    if (raw is List) {
      for (final entry in raw) {
        final item = _fromMap(entry);
        if (item == null) continue;
        final k = keyOf(item);
        if (_items.containsKey(k)) continue;
        _items[k] = item;
        added.add(item);
      }
    }
    return added;
  }

  /// 从日期桶名解析日期（`d:yyyy-MM-dd`）
  static DateTime? _bucketDay(String key) {
    const start = _dayPrefix.length;
    if (key.length != start + 10) return null;
    final y = int.tryParse(key.substring(start, start + 4));
    final m = int.tryParse(key.substring(start + 5, start + 7));
    final d = int.tryParse(key.substring(start + 8, start + 10));
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  static int? cursorOf(int mid) => _cursors[mid];

  static void setCursor(int mid, int cursor) {
    if (_cursors[mid] == cursor) return;
    _cursors[mid] = cursor;
  }

  static int? baselineOf(int mid) => _baselines[mid];

  static void setBaseline(int mid, int pubdate) {
    final old = _baselines[mid] ?? 0;
    if (pubdate > old) _baselines[mid] = pubdate;
  }

  static void merge(Iterable<VListItemModel> list) {
    for (final item in list) {
      // 没有发布时间无法按天归档，只留在内存里展示，不落盘
      if (dayOf(item.pubdate) == null) continue;
      final key = keyOf(item);
      if (key.isEmpty) continue;
      _items[key] = item;
      _dirtyDays.add(_bucketKey(item.pubdate));
    }
  }

  static String _bucketKey(int? pubdate) => '$_dayPrefix${dayKeyOf(pubdate)}';

  /// 保留窗口的起始日（本地时区，按天对齐）
  static DateTime cutoffOf(int keepDays) {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: keepDays));
  }

  /// 无发布时间或早于保留窗口即视为过期
  static bool expired(int? pubdate, DateTime cutoff) {
    final day = dayOf(pubdate);
    return day == null || day.isBefore(cutoff);
  }

  /// 清理已取关的 UP 与过期日桶，只在刷新时调用
  static void prune({required Set<int> followedMids, required int keepDays}) {
    final cutoff = cutoffOf(keepDays);
    _items.removeWhere((_, item) {
      final mid = item.owner.mid;
      if (mid == null || !followedMids.contains(mid)) {
        _dirtyDays.add(_bucketKey(item.pubdate));
        return true;
      }
      if (expired(item.pubdate, cutoff)) {
        _dirtyDays.add(_bucketKey(item.pubdate));
        return true;
      }
      return false;
    });
    // 清理历史版本遗留的 unknown 桶
    final unknownBucket = '$_dayPrefix$_unknownDay';
    if (_box.containsKey(unknownBucket)) _dirtyDays.add(unknownBucket);
    // 还没加载的过期日桶直接删掉，避免一直挂在待加载列表里
    _pendingBuckets.removeWhere((key) {
      final day = _bucketDay(key);
      if (day == null || !day.isBefore(cutoff)) return false;
      _dirtyDays.add(key);
      return true;
    });
    _cursors.removeWhere((mid, _) => !followedMids.contains(mid));
    _baselines.removeWhere((mid, _) => !followedMids.contains(mid));
  }

  /// 串行写入队列，保证多次 flush/clear 按调用顺序落盘
  static Future<void> _writeQueue = Future<void>.value();

  static Future<void> _enqueue(Future<void> Function() task) {
    final future = _writeQueue.catchError((_) {}).then((_) => task());
    _writeQueue = future.catchError((_) {});
    return future;
  }

  /// 增量落盘：只写变更的日桶（空桶即删除），并同步游标与基线。
  /// 快照在调用时同步生成，写入异步串行，不阻塞刷新。
  static Future<void> flush() {
    // 一次遍历把脏桶装满，避免「每个脏桶都扫一遍全量条目」
    final buckets = <String, List<Map<String, dynamic>>>{
      for (final key in _dirtyDays) key: <Map<String, dynamic>>[],
    };
    if (buckets.isNotEmpty) {
      for (final item in _items.values) {
        buckets[_bucketKey(item.pubdate)]?.add(_toMap(item));
      }
    }
    _dirtyDays.clear();
    final cursors = {
      for (final entry in _cursors.entries) '${entry.key}': entry.value,
    };
    final baselines = {
      for (final entry in _baselines.entries) '${entry.key}': entry.value,
    };
    return _enqueue(() async {
      final box = _box;
      for (final entry in buckets.entries) {
        if (entry.value.isEmpty) {
          await box.delete(entry.key);
        } else {
          await box.put(entry.key, entry.value);
        }
      }
      await box.put(_cursorsKey, cursors);
      await box.put(_baselineKey, baselines);
    });
  }

  static Future<void> clear() {
    _items.clear();
    _cursors.clear();
    _baselines.clear();
    _dirtyDays.clear();
    _pendingBuckets.clear();
    return _enqueue(() => _box.clear());
  }

  static Map<String, dynamic> _toMap(VListItemModel item) => {
    'pic': item.cover,
    'description': item.desc,
    'title': item.title,
    'created': item.pubdate,
    'length': item.duration > 0
        ? DurationUtils.formatDuration(item.duration)
        : null,
    'aid': item.aid,
    'bvid': item.bvid,
    'play': item.stat.view,
    'video_review': item.stat.danmu,
    'mid': item.owner.mid,
    'author': item.owner.name,
    'is_lesson_video': item.isPugv == true ? 1 : 0,
    'badge': item.badge,
    'season_id': item.seasonId,
    'jump_url': item.redirectUrl,
  };

  static VListItemModel? _fromMap(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    if (map['title'] == null || (map['bvid'] == null && map['aid'] == null)) {
      return null;
    }
    final item = VListItemModel.fromJson(map);
    final badge = map['badge'];
    if (badge is String && badge.isNotEmpty) item.badge = badge;
    return item;
  }
}
