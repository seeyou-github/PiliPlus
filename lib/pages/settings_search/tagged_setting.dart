import 'package:PiliPlus/models/common/setting_type.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';

/// 带分类信息的设置项，用于在搜索结果中标注该项所属的分类
class TaggedSetting {
  const TaggedSetting({required this.type, required this.model});

  /// 所属设置分类
  final SettingType type;

  /// 设置项本身
  final SettingsModel model;

  /// 分类名称
  String get category => type.title;
}
