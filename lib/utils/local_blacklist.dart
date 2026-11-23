import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/storage_pref.dart';

/// 本地黑名单
///
/// 在原有「按 UID 屏蔽」的基础上，新增「按昵称屏蔽」，昵称支持通配符：
/// - `*` 匹配任意个字符（包括空）
/// - `?` 匹配单个字符
///
/// 匹配不区分大小写，例如 `*官方*`、`张?`、`*资讯`
///
/// 与 [GlobalData.blackMids] 共用同一份本地数据，新增的属性 [names] 单独存放，
/// 不会影响原有 UID 黑名单的读写与导入导出。
class LocalBlacklist {
  LocalBlacklist._();

  static List<String>? _names;
  static List<String>? _cachedPatterns;
  static int _version = 0;
  static int _cachedVersion = -1;

  /// 昵称黑名单（保持用户添加顺序，可含通配符）
  static List<String> get names => _names ??= Pref.blackNames;

  /// 昵称匹配规则数量，用于外部判断是否需要展示
  static bool get hasNames => names.isNotEmpty;

  static List<String>? get _patterns {
    if (_cachedVersion != _version) {
      _cachedVersion = _version;
      _cachedPatterns = _buildPatterns(names);
    }
    return _cachedPatterns;
  }

  static List<String>? _buildPatterns(List<String> patterns) {
    final list = <String>[];
    for (final pattern in patterns) {
      final p = pattern.trim().toLowerCase();
      if (p.isNotEmpty) {
        list.add(p);
      }
    }
    return list.isEmpty ? null : list;
  }

  /// 昵称是否命中黑名单（支持通配符）
  static bool containsName(Object? name) {
    if (name == null) return false;
    final patterns = _patterns;
    if (patterns == null) return false;
    final value = (name is String ? name : name.toString()).toLowerCase();
    if (value.isEmpty) return false;
    for (final pattern in patterns) {
      if (_globMatch(pattern, value)) return true;
    }
    return false;
  }

  /// 线性匹配 glob 模式，避免正则回溯在多个 `*` 时退化
  static bool _globMatch(String pattern, String value) {
    var p = 0;
    var v = 0;
    var star = -1;
    var mark = 0;
    while (v < value.length) {
      if (p < pattern.length) {
        final c = pattern.codeUnitAt(p);
        // ? 匹配任意单个字符
        if (c == 0x3F || c == value.codeUnitAt(v)) {
          p++;
          v++;
          continue;
        }
        // * 匹配任意长度的字符序列
        if (c == 0x2A) {
          star = p++;
          mark = v;
          continue;
        }
      }
      if (star == -1) return false;
      p = star + 1;
      v = ++mark;
    }
    while (p < pattern.length && pattern.codeUnitAt(p) == 0x2A) {
      p++;
    }
    return p == pattern.length;
  }

  /// UID 是否命中黑名单（兼容 int/num/String 形式的 mid）
  static bool containsMid(Object? mid) {
    if (mid == null) return false;
    final int? id = switch (mid) {
      int() => mid,
      num() => mid.toInt(),
      _ => int.tryParse(mid.toString()),
    };
    return id != null && GlobalData().blackMids.contains(id);
  }

  /// UID 或昵称任一命中即视为已屏蔽
  static bool blocked({Object? mid, Object? name}) =>
      containsMid(mid) || containsName(name);

  static void addMid(Object? mid) {
    if (mid == null) return;
    final id = mid is int ? mid : int.tryParse(mid.toString());
    if (id == null) return;
    Pref.setBlackMid(id);
  }

  /// 批量添加并立即持久化（导入黑名单时使用）
  static void addMids(Iterable<int> mids) {
    if (mids.isEmpty) return;
    final blackMids = GlobalData().blackMids..addAll(mids);
    Pref.blackMids = blackMids;
  }

  static void removeMid(int mid) => Pref.removeBlackMid(mid);

  /// 添加昵称规则（自动去首尾空格，重复则不重复添加）
  static bool addName(String name) {
    final value = name.trim();
    if (value.isEmpty) return false;
    final list = names;
    if (list.contains(value)) return false;
    list.add(value);
    _persist();
    return true;
  }

  static bool removeName(String name) {
    final removed = names.remove(name);
    if (removed) _persist();
    return removed;
  }

  /// 就地从列表中移除命中黑名单的条目（[nameOf] 不传时只按 UID 判断）
  static void removeBlocked<E>(
    List<E>? list,
    Object? Function(E element) midOf, [
    Object? Function(E element)? nameOf,
  ]) {
    if (list == null || list.isEmpty) return;
    list.removeWhere(
      (e) => blocked(mid: midOf(e), name: nameOf?.call(e)),
    );
  }

  /// 覆盖式导入昵称列表
  static void setNames(Iterable<String> values) {
    final list = names..clear();
    for (final value in values) {
      final v = value.trim();
      if (v.isNotEmpty && !list.contains(v)) {
        list.add(v);
      }
    }
    _persist();
  }

  /// 重新从本地存储加载昵称规则（整体导入配置后调用）
  static void reload() {
    _names = null;
    _version++;
  }

  static void _persist() {
    Pref.blackNames = names;
    _version++;
  }
}
