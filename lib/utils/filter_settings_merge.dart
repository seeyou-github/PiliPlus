import 'package:PiliPlus/utils/storage_key.dart';

/// 屏蔽过滤设置在导入时的合并逻辑
///
/// 「恢复设置 / 导入设置 / 导入所有数据」会整体替换设置项，这里把用户在本机
/// 积累的关键词过滤内容与导入内容取并集，避免被备份文件覆盖：
/// - 标题关键词过滤 [SettingBoxKey.banWordForRecommend]
/// - 分区关键词过滤 [SettingBoxKey.banWordForZone]
/// - 评论关键词过滤 [SettingBoxKey.banWordForReply]
/// - 动态关键词过滤 [SettingBoxKey.banWordForDyn]
///
/// 黑名单存放在 localCache，由归档导入逻辑单独合并。
abstract final class FilterSettingsMerge {
  /// 需要按并集合并的关键词过滤设置项
  static const banWordKeys = [
    SettingBoxKey.banWordForRecommend,
    SettingBoxKey.banWordForZone,
    SettingBoxKey.banWordForReply,
    SettingBoxKey.banWordForDyn,
  ];

  /// 生成合并后的 setting 数据：关键词项取并集，其余项保持导入值
  static Map<dynamic, dynamic> mergeSettings(
    Map<dynamic, dynamic> imported,
    Map<dynamic, dynamic> current,
  ) {
    final merged = Map<dynamic, dynamic>.from(imported);
    for (final key in banWordKeys) {
      merged[key] = mergeBanWord(current[key], imported[key]);
    }
    return merged;
  }

  /// 合并两个 `|` 分隔的关键词表达式
  ///
  /// 保留当前设备的条目，再追加导入中独有的条目；条目保持原有文本，
  /// 只去掉空项与完全重复项，不改变正则表达式语义。
  static String mergeBanWord(Object? current, Object? imported) {
    final existing = current is String ? current : '';
    final incoming = imported is String ? imported : '';
    if (incoming.isEmpty) return existing;
    if (existing.isEmpty) return incoming;

    final seen = <String>{};
    final result = <String>[];
    for (final word in [...existing.split('|'), ...incoming.split('|')]) {
      if (word.isEmpty) continue;
      if (seen.add(word)) result.add(word);
    }
    return result.join('|');
  }
}
