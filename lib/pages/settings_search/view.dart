import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/view_insets_safe_area.dart';
import 'package:PiliPlus/common/widgets/view_sliver_safe_area.dart';
import 'package:PiliPlus/models/common/setting_type.dart';
import 'package:PiliPlus/pages/search/controller.dart' show DebounceStreamState;
import 'package:PiliPlus/pages/settings_search/tagged_setting.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/waterfall.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class SettingsSearchPage extends StatefulWidget {
  const SettingsSearchPage({super.key});

  @override
  State<SettingsSearchPage> createState() => _SettingsSearchPageState();
}

class _SettingsSearchPageState
    extends DebounceStreamState<SettingsSearchPage, String> {
  final _textEditingController = TextEditingController();
  final RxList<TaggedSetting> _list = <TaggedSetting>[].obs;
  late final _settings = [
    ..._tagSettings(SettingType.extraSetting),
    ..._tagSettings(SettingType.dmSetting),
    ..._tagSettings(SettingType.replySetting),
    ..._tagSettings(SettingType.dynSetting),
    ..._tagSettings(SettingType.privacySetting),
    ..._tagSettings(SettingType.recommendSetting),
    ..._tagSettings(SettingType.videoSetting),
    ..._tagSettings(SettingType.playSetting),
    ..._tagSettings(SettingType.styleSetting),
  ];

  /// 把某一分类下的设置项包装成带分类名的结果项
  static Iterable<TaggedSetting> _tagSettings(SettingType type) =>
      type.settings.map((e) => TaggedSetting(type: type, model: e));

  @override
  void onValueChanged(String value) {
    if (value.isEmpty) {
      _list.clear();
    } else {
      value = value.toLowerCase();
      _list.value = _settings
          .where(
            (item) =>
                item.model.effectiveTitle.toLowerCase().contains(value) ||
                item.model.effectiveSubtitle?.toLowerCase().contains(value) ==
                    true,
          )
          .toList();
    }
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SimpleScaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () {
              if (_textEditingController.text.isNotEmpty) {
                _textEditingController.clear();
                _list.clear();
              } else {
                Get.back();
              }
            },
            icon: const Icon(Icons.clear),
          ),
          const SizedBox(width: 10),
        ],
        title: TextField(
          autofocus: true,
          controller: _textEditingController,
          textAlignVertical: TextAlignVertical.center,
          onChanged: ctr!.add,
          decoration: const InputDecoration(
            isDense: true,
            hintText: '搜索',
            visualDensity: .standard,
            border: InputBorder.none,
          ),
        ),
      ),
      body: ViewInsetsSafeArea(
        child: CustomScrollView(
          slivers: [
            ViewSliverSafeArea(
              sliver: Obx(
                () => _list.isEmpty
                    ? const HttpError()
                    : SliverMasonryGrid(
                        gridDelegate: gridDelegate,
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = _list[index];
                            return Column(
                              mainAxisSize: .min,
                              crossAxisAlignment: .start,
                              children: [
                                Padding(
                                  padding: const .only(left: 6, bottom: 6),
                                  child: Text(
                                    item.category,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: ColorScheme.of(context).primary,
                                    ),
                                  ),
                                ),
                                item.model.widget,
                              ],
                            );
                          },
                          childCount: _list.length,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  late final gridDelegate = SliverSimpleGridDelegateWithMaxCrossAxisExtent_(
    maxCrossAxisExtent: Grid.smallCardWidth * 2,
  );
}
