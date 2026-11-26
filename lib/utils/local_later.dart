import 'package:PiliPlus/models/local/local_later_item.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';

/// 本地稍后再看（未登录时使用）
///
/// 只读写独立的 `localLater` box：
/// - 不写入设置 box，改动不会触发设置变更 / 自动备份；
/// - 不在任何导出、WebDAV 备份、同步逻辑里出现，仅限本设备浏览。
abstract final class LocalLater {
  /// 最多保留的条数，超出后丢弃最早加入的
  static const int maxEntries = 100;

  /// 条数（「我的」页入口的角标）
  static final count = 0.obs;

  /// 内容版本号：增删都自增，按钮与列表据此刷新
  static final revision = 0.obs;

  static bool _loaded = false;
  static final Map<String, LocalLaterItem> _items = {};

  static Box<dynamic> get _box => GStorage.localLater;

  static void ensureLoaded() {
    if (_loaded) return;
    _loaded = true;
    for (final entry in _box.toMap().entries) {
      final item = LocalLaterItem.fromMap(entry.value);
      if (item != null) _items[item.key] = item;
    }
    // 上限下调或历史数据超限时，加载后按上限裁剪一次
    _prune();
    count.value = _items.length;
  }

  /// 稍后再看列表，最近加入的在前
  static List<LocalLaterItem> get items {
    ensureLoaded();
    return _items.values.toList()
      ..sort((a, b) => b.addTime.compareTo(a.addTime));
  }

  /// 是否已在本地稍后再看
  static bool contains(String? bvid) {
    if (bvid == null || bvid.isEmpty) return false;
    ensureLoaded();
    // 读一次版本号，让调用方的 Obx 能订阅到增删变化
    final _ = revision.value;
    return _items.containsKey(bvid);
  }

  /// 切换：返回 true 表示已加入，false 表示已移出，null 表示无法处理（缺少 bvid）
  static bool? toggle({
    required String? bvid,
    int cid = 0,
    String title = '',
    String? cover,
    String? ownerName,
    int? ownerMid,
    int duration = 0,
  }) {
    if (bvid == null || bvid.isEmpty) return null;
    if (contains(bvid)) {
      remove(bvid);
      return false;
    }
    add(
      bvid: bvid,
      cid: cid,
      title: title,
      cover: cover,
      ownerName: ownerName,
      ownerMid: ownerMid,
      duration: duration,
    );
    return true;
  }

  static void add({
    required String bvid,
    int cid = 0,
    String title = '',
    String? cover,
    String? ownerName,
    int? ownerMid,
    int duration = 0,
  }) {
    if (bvid.isEmpty) return;
    ensureLoaded();
    final old = _items[bvid];
    final item = LocalLaterItem(
      bvid: bvid,
      cid: cid > 0 ? cid : (old?.cid ?? 0),
      title: title.isNotEmpty ? title : (old?.title ?? ''),
      cover: cover ?? old?.cover,
      ownerName: ownerName ?? old?.ownerName,
      ownerMid: ownerMid ?? old?.ownerMid,
      duration: duration > 0 ? duration : (old?.duration ?? 0),
      addTime: DateTime.now().millisecondsSinceEpoch,
    );
    _items[bvid] = item;
    _box.put(bvid, item.toMap());
    _prune();
    count.value = _items.length;
    revision.value++;
  }

  static void remove(String bvid) {
    ensureLoaded();
    if (_items.remove(bvid) == null) return;
    _box.delete(bvid);
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
      ..sort((a, b) => a.addTime.compareTo(b.addTime));
    // 先算好要删的条数，循环里 _items 长度会变
    final removeCount = _items.length - maxEntries;
    for (var i = 0; i < removeCount; i++) {
      final key = sorted[i].key;
      _items.remove(key);
      _box.delete(key);
    }
  }
}
