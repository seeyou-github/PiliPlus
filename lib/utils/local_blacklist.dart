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
  static RegExp? _cachedRegExp;
  static int _version = 0;
  static int _cachedVersion = -1;

  /// 昵称黑名单（保持用户添加顺序，可含通配符）
  static List<String> get names => _names ??= Pref.blackNames;

  /// 昵称匹配规则数量，用于外部判断是否需要展示
  static bool get hasNames => names.isNotEmpty;

  static RegExp? get _regExp {
    if (_cachedVersion != _version) {
      _cachedVersion = _version;
      _cachedRegExp = _buildRegExp(names);
    }
    return _cachedRegExp;
  }

  static RegExp? _buildRegExp(List<String> patterns) {
    final list = <String>[];
    for (final pattern in patterns) {
      final p = pattern.trim();
      if (p.isNotEmpty) {
        list.add(_toRegExpString(p));
      }
    }
    if (list.isEmpty) return null;
    return RegExp('^(?:${list.join('|')})\$', caseSensitive: false);
  }

  /// 把通配符字符串转为正则片段（其余字符全部转义）
  static String _toRegExpString(String pattern) {
    final sb = StringBuffer();
    for (final rune in pattern.runes) {
      switch (rune) {
        case 0x2A: // *
          sb.write('.*');
        case 0x3F: // ?
          sb.write('.');
        default:
          sb.write(RegExp.escape(String.fromCharCode(rune)));
      }
    }
    return sb.toString();
  }

  /// 昵称是否命中黑名单（支持通配符）
  static bool containsName(Object? name) {
    if (name == null) return false;
    final regExp = _regExp;
    if (regExp == null) return false;
    final value = name is String ? name : name.toString();
    return value.isNotEmpty && regExp.hasMatch(value);
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
