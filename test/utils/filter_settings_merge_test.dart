import 'package:PiliPlus/utils/filter_settings_merge.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('合并关键词时保留现有条目并追加导入独有项', () {
    expect(
      FilterSettingsMerge.mergeBanWord('尝试|测试', '测试|广告'),
      '尝试|测试|广告',
    );
  });

  test('导入为空时保留现有内容', () {
    expect(FilterSettingsMerge.mergeBanWord('尝试|测试', ''), '尝试|测试');
    expect(FilterSettingsMerge.mergeBanWord('尝试', null), '尝试');
  });

  test('现有为空时直接使用导入内容', () {
    expect(FilterSettingsMerge.mergeBanWord('', '广告|推广'), '广告|推广');
  });

  test('合并时去掉空项', () {
    expect(FilterSettingsMerge.mergeBanWord('a||b', '|b|c|'), 'a|b|c');
  });

  test('导入设置只合并关键词项，其余项保持导入值', () {
    const otherKey = 'otherSetting';
    const current = {
      SettingBoxKey.banWordForRecommend: '本机',
      SettingBoxKey.banWordForReply: '本机评论',
      otherKey: '本机其它',
    };
    const imported = {
      SettingBoxKey.banWordForRecommend: '备份',
      SettingBoxKey.banWordForZone: '备份分区',
      otherKey: '导入其它',
    };

    final merged = FilterSettingsMerge.mergeSettings(imported, current);

    expect(merged[SettingBoxKey.banWordForRecommend], '本机|备份');
    expect(merged[SettingBoxKey.banWordForZone], '备份分区');
    expect(merged[SettingBoxKey.banWordForReply], '本机评论');
    expect(merged[otherKey], '导入其它');
  });
}
