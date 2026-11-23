import 'package:PiliPlus/pages/setting/models/dyn_settings.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/pages/setting/models/privacy_settings.dart';
import 'package:PiliPlus/pages/setting/models/recommend_settings.dart';
import 'package:PiliPlus/pages/setting/models/reply_settings.dart';

/// 「屏蔽过滤设置」中的一个子分组
///
/// 设置项本身仍定义在各自原有分类文件中（通过 xxxFilterSettings 暴露），
/// 这里只负责分组聚合，便于以后与上游合并时减少冲突
class FilterSettingGroup {
  const FilterSettingGroup({required this.title, required this.settings});

  /// 分组标题（来源分类名）
  final String title;

  /// 该分组下的设置项
  final List<SettingsModel> settings;
}

/// 屏蔽过滤设置的分组列表，顺序：隐私 → 推荐流 → 评论 → 动态
List<FilterSettingGroup> get filterSettingGroups => [
  FilterSettingGroup(title: '隐私设置', settings: privacyFilterSettings),
  FilterSettingGroup(title: '推荐流设置', settings: recommendFilterSettings),
  FilterSettingGroup(title: '评论设置', settings: replyFilterSettings),
  FilterSettingGroup(title: '动态设置', settings: dynFilterSettings),
];

/// 扁平化的全部屏蔽过滤设置项（供设置搜索使用）
List<SettingsModel> get filterSettings => [
  for (final group in filterSettingGroups) ...group.settings,
];
