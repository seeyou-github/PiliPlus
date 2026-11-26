import 'package:PiliPlus/models/local/local_history_item.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';

/// 本地观看记录（未登录时使用）
///
/// 只读写独立的 `localHistory` box：
/// - 不写入设置 box，改动不会触发设置变更 / 自动备份；
/// - 不在任何导出、WebDAV 备份、同步逻辑里出现，仅限本设备浏览。
abstract final class LocalHistory {
  /// 最多保留的记录条数，超出后丢弃最早的
  static const int maxEntries = 100;

  /// 记录条数（未登录时「我的」页入口的角标）
  static final count = 0.obs;

  /// 记录内容版本号：增删改都自增，列表页据此刷新（条数不变时也能更新）
  static final revision = 0.obs;

  static bool _loaded = false;
  static final Map<String, LocalHistoryItem> _items = {};

  static Box<dynamic> get _box => GStorage.localHistory;

  static void ensureLoaded() {
    if (_loaded) return;
    _loaded = true;
    for (final entry in _box.toMap().entries) {
      final item = LocalHistoryItem.fromMap(entry.value);
      if (item != null) _items[item.key] = item;
    }
    // 上限下调后，旧数据也要按新上限裁剪一次
    _prune();
    count.value = _items.length;
  }

  /// 观看记录，最近观看的在前
  static List<LocalHistoryItem> get items {
    ensureLoaded();
    return _items.values.toList()
      ..sort((a, b) => b.watchTime.compareTo(a.watchTime));
  }

  /// 记录一次观看：同一视频（同一分P）只保留一条，并刷新观看时间
  static void record({
    required String bvid,
    required int cid,
    required String title,
    String? cover,
    String? ownerName,
    int? ownerMid,
    int duration = 0,
  }) {
    if (bvid.isEmpty || cid <= 0) return;
    ensureLoaded();
    final key = '$bvid:$cid';
    final old = _items[key];
    final item = LocalHistoryItem(
      bvid: bvid,
      cid: cid,
      // 详情还没回来时先占位，后续补全时以新数据为准
      title: title.isNotEmpty ? title : (old?.title ?? ''),
      cover: cover ?? old?.cover,
      ownerName: ownerName ?? old?.ownerName,
      ownerMid: ownerMid ?? old?.ownerMid,
      duration: duration > 0 ? duration : (old?.duration ?? 0),
      watchTime: DateTime.now().millisecondsSinceEpoch,
      progress: old?.progress ?? 0,
    );
    _items[key] = item;
    _box.put(key, item.toMap());
    _prune();
    count.value = _items.length;
    revision.value++;
  }

  /// 更新上次播放进度（毫秒）；片头 3 秒内不记，避免"点开就退"也算进度
  static void updateProgress({
    required String bvid,
    required int cid,
    required int progress,
  }) {
    if (progress < 3000) return;
    ensureLoaded();
    final key = '$bvid:$cid';
    final old = _items[key];
    if (old == null || old.progress == progress) return;
    final item = old.copyWith(progress: progress);
    _items[key] = item;
    _box.put(key, item.toMap());
    revision.value++;
  }

  static void remove(String key) {
    ensureLoaded();
    if (_items.remove(key) == null) return;
    _box.delete(key);
    count.value = _items.length;
    revision.value++;
  }

  static Future<void> clear() async {
    _items.clear();
    await _box.clear();
    count.value = 0;
    revision.value++;
  }

  static void _prune() {
    if (_items.length <= maxEntries) return;
    final sorted = _items.values.toList()
      ..sort((a, b) => a.watchTime.compareTo(b.watchTime));
    // 先算好要删的条数，循环里 _items 长度会变
    final removeCount = _items.length - maxEntries;
    for (var i = 0; i < removeCount; i++) {
      final key = sorted[i].key;
      _items.remove(key);
      _box.delete(key);
    }
  }
}
