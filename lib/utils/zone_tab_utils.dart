import 'package:PiliPlus/models/common/rank_type.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';

/// 分区tab显示与排序配置
/// 独立成类，避免与上游 RankType/RankController 改动产生冲突
class ZoneTabUtils {
  ZoneTabUtils._();

  /// 分区编辑页的存储键
  static const String storageKey = SettingBoxKey.zoneTabSort;

  /// 全部分区（默认全部显示）
  static List<RankType> get allTypes => RankType.values;

  /// 读取用户配置的分区列表（已过滤 + 已排序）
  /// 未配置或配置异常时回退为全部分区
  static List<RankType> get visibleTypes {
    final cache = GStorage.setting.get(storageKey);
    if (cache is List) {
      final list = <RankType>[];
      for (final e in cache) {
        if (e is int && e >= 0 && e < RankType.values.length) {
          final type = RankType.values[e];
          if (!list.contains(type)) list.add(type);
        }
      }
      if (list.isNotEmpty) return list;
    }
    return allTypes;
  }

  /// 将配置保存为分区枚举 index 列表
  static List<int> toIndexList(List<RankType> types) =>
      types.map((e) => e.index).toList();
}
