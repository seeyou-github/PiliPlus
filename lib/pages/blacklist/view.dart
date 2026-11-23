import 'package:PiliPlus/common/skeleton/msg_feed_top.dart';
import 'package:PiliPlus/common/sliver_single_child_delegate.dart';
import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/common/widgets/dialog/export_import.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/scroll_physics.dart';
import 'package:PiliPlus/common/widgets/sliver_wrap.dart';
import 'package:PiliPlus/common/widgets/view_sliver_safe_area.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/enum_with_label.dart';
import 'package:PiliPlus/models/common/image_type.dart';
import 'package:PiliPlus/models_new/blacklist/list.dart';
import 'package:PiliPlus/pages/blacklist/controller.dart';
import 'package:PiliPlus/pages/search/widgets/search_text.dart';
import 'package:PiliPlus/utils/date_utils.dart';
import 'package:PiliPlus/utils/local_blacklist.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

enum _BlockType implements EnumWithLabel {
  local('本地'),
  online('在线'),
  ;

  @override
  final String label;

  _BlockType(this.label);
}

/// 本地黑名单条目的展示模型（UID 或 昵称规则）
class _LocalBlockEntry {
  final String text;

  /// 为 null 表示昵称规则（通配符），否则为 UID
  final int? mid;

  const _LocalBlockEntry({required this.text, this.mid});

  bool get isName => mid == null;
}

class BlackListPage extends StatefulWidget {
  const BlackListPage({super.key});

  @override
  State<BlackListPage> createState() => _BlackListPageState();
}

class _BlackListPageState extends State<BlackListPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _blackListController = Get.put(BlackListController());
  late EdgeInsets padding;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _BlockType.values.length,
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    padding = MediaQuery.viewPaddingOf(context);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SimpleScaffold(
      appBar: AppBar(title: const Text('黑名单管理')),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: _BlockType.values.map((e) => Tab(text: e.label)).toList(),
          ),
          Expanded(
            child: tabBarView(
              controller: _tabController,
              children: _BlockType.values
                  .map(
                    (e) => switch (e) {
                      _BlockType.local => _local,
                      _BlockType.online => _online,
                    },
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget get _online {
    return refreshIndicator(
      onRefresh: _blackListController.onRefresh,
      child: CustomScrollView(
        key: const PageStorageKey(_BlockType.online),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          ViewSliverSafeArea(
            sliver: Obx(
              () => _buildBody(_blackListController.loadingState.value),
            ),
          ),
        ],
      ),
    );
  }

  void _onAddBlock(String value) {
    final text = value.trim();
    if (text.isEmpty) return;
    // 纯数字按 UID 处理，其余按昵称（支持 * ? 通配符）
    if (RegExp(r'^\d+$').hasMatch(text)) {
      final intMid = int.tryParse(text);
      if (intMid == null || intMid <= 0) {
        SmartDialog.showToast('请输入正确的UID');
        return;
      }
      if (_blackListController.blackMids.contains(intMid)) {
        SmartDialog.showToast('该UID已在黑名单中');
        return;
      }
      _blackListController.blackMids.add(intMid);
      LocalBlacklist.addMid(intMid);
    } else {
      if (!LocalBlacklist.addName(text)) {
        SmartDialog.showToast('该昵称规则已存在');
        return;
      }
    }
    SmartDialog.showToast('屏蔽成功');
    setState(() {});
  }

  void _showAddMidDialog() {
    var text = '';
    final colorScheme = ColorScheme.of(context);
    showConfirmDialog(
      context: context,
      title: const Text('屏蔽用户'),
      content: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: [
          TextField(
            autofocus: true,
            textInputAction: .done,
            onChanged: (value) => text = value,
            onSubmitted: (value) {
              Get.back();
              _onAddBlock(value);
            },
            decoration: const InputDecoration(
              labelText: 'UID 或昵称',
              hintText: '如 123456 或 *官方*',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '用法：\n'
            '· 纯数字按 UID 屏蔽\n'
            '· 其它内容按昵称屏蔽，支持通配符\n'
            '· * 匹配任意个字符，? 匹配单个字符\n'
            '· 不区分大小写，如 *官方*、张?、*资讯',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: colorScheme.outline,
            ),
          ),
        ],
      ),
      onConfirm: () => _onAddBlock(text),
    );
  }

  /// 本地黑名单条目：昵称规则在前，UID 在后
  List<_LocalBlockEntry> get _localEntries => [
    for (final name in LocalBlacklist.names) _LocalBlockEntry(text: name),
    for (final mid in _blackListController.blackMids)
      _LocalBlockEntry(text: mid.toString(), mid: mid),
  ];

  void _showImportExportDialog() {
    showImportExportDialog<List>(
      context,
      title: '黑名单',
      localFileName: () => 'blackMids',
      onExport: () => Utils.jsonEncoder.convert([
        ..._blackListController.blackMids,
        ...LocalBlacklist.names,
      ]),
      onImport: (json) {
        // 兼容旧格式（纯 UID 数组）与新格式（UID + 昵称混合数组）
        final mids = json.whereType<int>().toSet();
        final names = json.whereType<String>();
        if (mids.isNotEmpty) {
          _blackListController.blackMids.addAll(mids);
        }
        if (names.isNotEmpty) {
          LocalBlacklist.setNames({...LocalBlacklist.names, ...names});
        }
        setState(() {});
      },
    );
  }

  Widget get _local {
    final entries = _localEntries;
    final colorScheme = ColorScheme.of(context);
    return ScaffoldLayout(
      fab: Padding(
        padding: .only(
          right: kFloatingActionButtonMargin + padding.right,
          bottom: kFloatingActionButtonMargin + padding.bottom,
        ),
        child: Column(
          spacing: kFloatingActionButtonMargin,
          mainAxisSize: .min,
          children: [
            FloatingActionButton(
              tooltip: '导入/导出',
              onPressed: _showImportExportDialog,
              child: const Icon(Icons.swap_vert, size: 26),
            ),
            FloatingActionButton(
              tooltip: '添加',
              onPressed: _showAddMidDialog,
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ),
      body: CustomScrollView(
        key: const PageStorageKey(_BlockType.local),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          ViewSliverSafeArea(
            bottom: 180,
            sliver: SliverPadding(
              padding: const .fromLTRB(12, 12, 12, 0),
              sliver: SliverFixedWrap(
                spacing: 8,
                runSpacing: 8,
                mainAxisExtent: 30,
                delegate: SliverChildBuilderDelegate(
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: false,
                  childCount: entries.length,
                  (context, index) {
                    final entry = entries[index];
                    return SearchText(
                      text: entry.text,
                      bgColor: entry.isName
                          ? colorScheme.secondaryContainer
                          : null,
                      onTap: entry.isName
                          ? null
                          : (mid) => Get.toNamed('/member?mid=$mid'),
                      onLongPress: (_) => showConfirmDialog(
                        context: context,
                        title: Text(
                          entry.isName ? '确定移除该昵称规则？' : '确定移除该用户？',
                        ),
                        onConfirm: () {
                          if (entry.isName) {
                            LocalBlacklist.removeName(entry.text);
                          } else {
                            _blackListController.blackMids.remove(entry.mid);
                          }
                          setState(() {});
                        },
                      ),
                      height: 1,
                      maxLines: 1,
                      fontSize: 14,
                      overflow: .ellipsis,
                      padding: const .fromLTRB(11, 8, 11, 0),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(LoadingState<List<BlackListItem>?> loadingState) {
    late final style = TextStyle(color: Theme.of(context).colorScheme.outline);
    return switch (loadingState) {
      Loading() => const SliverPrototypeExtentList(
        prototypeItem: MsgFeedTopSkeleton(),
        delegate: SliverSingleChildDelegate(
          count: 12,
          child: MsgFeedTopSkeleton(),
        ),
      ),
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? SliverList.builder(
                itemCount: response.length,
                itemBuilder: (BuildContext context, int index) {
                  if (index == response.length - 1) {
                    _blackListController.onLoadMore();
                  }
                  final item = response[index];
                  return ListTile(
                    visualDensity: .standard,
                    onTap: () => Get.toNamed('/member?mid=${item.mid}'),
                    leading: NetworkImgLayer(
                      width: 45,
                      height: 45,
                      type: ImageType.avatar,
                      src: item.face,
                    ),
                    title: Text(
                      item.uname!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      '添加时间: ${DateFormatUtils.format(item.mtime, format: DateFormatUtils.longFormatDs)}',
                      maxLines: 1,
                      style: style,
                      overflow: TextOverflow.ellipsis,
                    ),
                    dense: true,
                    trailing: TextButton(
                      onPressed: () async {
                        final removed = await _blackListController.onRemove(
                          context,
                          index,
                          item.uname,
                          item.mid,
                        );
                        if (mounted && removed) {
                          if (_blackListController.blackMids.remove(item.mid)) {
                            setState(() {});
                          }
                        }
                      },
                      child: const Text('移除'),
                    ),
                  );
                },
              )
            : HttpError(onReload: _blackListController.onReload),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: _blackListController.onReload,
      ),
    };
  }
}
