import 'package:PiliPlus/common/widgets/pair.dart';
import 'package:PiliPlus/common/widgets/reorder_mixin.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/models/common/rank_type.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/zone_tab_utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// 分区编辑页：隐藏指定分区、拖动排序
/// 参考 BarSetPage 布局，独立实现以避免与其后续改动冲突
class ZoneSetPage extends StatefulWidget {
  const ZoneSetPage({super.key});

  @override
  State<ZoneSetPage> createState() => _ZoneSetPageState();
}

class _ZoneSetPageState extends State<ZoneSetPage> with ReorderMixin {
  late final List<Pair<RankType, bool>> list;
  late EdgeInsets padding;

  @override
  void initState() {
    super.initState();
    final cache = GStorage.setting.get(ZoneTabUtils.storageKey);
    final selected = <int>{};
    final order = <int>[];
    if (cache is List) {
      for (final e in cache) {
        if (e is int) {
          selected.add(e);
          order.add(e);
        }
      }
    }
    // 无配置时默认全部勾选
    final hasCache = order.isNotEmpty;
    list = RankType.values
        .map(
          (e) => Pair<RankType, bool>(
            first: e,
            second: hasCache ? selected.contains(e.index) : true,
          ),
        )
        .toList();
    if (hasCache) {
      final cacheIndex = {for (int i = 0; i < order.length; i++) order[i]: i};
      list.sort((a, b) {
        final indexA = cacheIndex[a.first.index] ?? cacheIndex.length;
        final indexB = cacheIndex[b.first.index] ?? cacheIndex.length;
        return indexA.compareTo(indexB);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viewPad = MediaQuery.viewPaddingOf(context);
    padding = .only(top: 10, right: viewPad.right + 34, bottom: viewPad.bottom);
  }

  void saveEdit() {
    final selected = list.where((e) => e.second).map((e) => e.first).toList();
    if (selected.isEmpty) {
      SmartDialog.showToast('请至少保留一个分区');
      return;
    }
    GStorage.setting.put(
      ZoneTabUtils.storageKey,
      ZoneTabUtils.toIndexList(selected),
    );
    SmartDialog.showToast('保存成功，下次启动时生效');
  }

  void onReset() {
    Get.back();
    GStorage.setting.delete(ZoneTabUtils.storageKey);
    SmartDialog.showToast('重置成功，下次启动时生效');
  }

  void onReorderItem(int oldIndex, int newIndex) {
    list.insert(newIndex, list.removeAt(oldIndex));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SimpleScaffold(
      appBar: AppBar(
        title: const Text('分区编辑'),
        actions: [
          TextButton(onPressed: onReset, child: const Text('重置')),
          TextButton(onPressed: saveEdit, child: const Text('保存')),
          const SizedBox(width: 12),
        ],
      ),
      body: ReorderableListView(
        onReorderItem: onReorderItem,
        proxyDecorator: proxyDecorator,
        footer: Padding(
          padding: padding,
          child: const Align(
            alignment: Alignment.centerRight,
            child: Text('*长按拖动排序'),
          ),
        ),
        children: list
            .map(
              (e) => CheckboxListTile(
                key: ValueKey(e.hashCode),
                value: e.second,
                onChanged: (bool? value) {
                  e.second = value!;
                  setState(() {});
                },
                title: Text(e.first.label),
                secondary: const Icon(Icons.drag_indicator_rounded),
              ),
            )
            .toList(),
      ),
    );
  }
}
