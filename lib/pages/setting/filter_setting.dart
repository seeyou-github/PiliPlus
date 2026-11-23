import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/models/common/setting_type.dart';
import 'package:PiliPlus/pages/setting/models/filter_settings.dart';
import 'package:material_ui/material_ui.dart';

/// 屏蔽过滤设置页
///
/// 与通用设置页的区别：按来源分类分块展示，同一分类的设置项放进同一个
/// 卡片容器，不同分类之间留出间隔
class FilterSetting extends StatelessWidget {
  const FilterSetting({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.viewPaddingOf(context);
    final colorScheme = ColorScheme.of(context);
    final labelStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: colorScheme.primary,
    );
    return SimpleScaffold(
      appBar: showAppBar
          ? AppBar(title: Text(SettingType.filterSetting.title))
          : null,
      body: ListView(
        padding: EdgeInsets.only(
          left: showAppBar ? padding.left : 0,
          right: showAppBar ? padding.right : 0,
          bottom: padding.bottom + 100,
        ),
        children: [
          for (final group in filterSettingGroups)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 6, bottom: 6),
                    child: Text(group.title, style: labelStyle),
                  ),
                  Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.hardEdge,
                    child: Column(
                      children: [
                        for (final item in group.settings) item.widget,
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
