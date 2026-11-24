import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/common/widgets/dialog/export_import.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/models/common/image_type.dart';
import 'package:PiliPlus/models/local/local_follow_item.dart';
import 'package:PiliPlus/utils/local_library.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// 本地关注列表（未登录时使用）
///
/// 数据来自 [LocalLibrary]，与在线关注完全隔离。
class LocalFollowPage extends StatelessWidget {
  const LocalFollowPage({super.key});

  /// 本地关注 + 本地收藏一起导入/导出（同一份本地数据）
  void _showImportExport(BuildContext context) {
    showImportExportDialog<Map>(
      context,
      title: '本地数据',
      localFileName: () => 'local',
      onExport: () => Utils.jsonEncoder.convert(LocalLibrary.exportJson()),
      onImport: (json) => LocalLibrary.importJson(json),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SimpleScaffold(
      appBar: AppBar(
        title: Obx(() => Text('本地关注 ${LocalLibrary.followCount.value}')),
        actions: [
          IconButton(
            tooltip: '导入/导出本地数据',
            onPressed: () => _showImportExport(context),
            icon: const Icon(Icons.swap_vert),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Obx(() {
        // 读取 Rx 计数以注册依赖，否则 Obx 零依赖会抛异常导致 body 空白
        final count = LocalLibrary.followCount.value;
        final follows = LocalLibrary.follows;
        if (count == 0 || follows.isEmpty) {
          return const _Empty();
        }
        return ListView.builder(
          padding: const .only(top: 4, bottom: 60),
          itemCount: follows.length,
          itemBuilder: (context, index) =>
              _FollowItemCard(item: follows[index]),
        );
      }),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const .symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: .min,
          spacing: 8,
          children: [
            Icon(
              Icons.person_add_alt_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            Text('还没有本地关注', style: TextStyle(color: theme.colorScheme.outline)),
            Text(
              '未登录时在播放页或 UP 主页点击「关注」，即可保存到本地',
              textAlign: .center,
              style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowItemCard extends StatelessWidget {
  final LocalFollowItem item;

  const _FollowItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: () => Get.toNamed('/member?mid=${item.mid}'),
      leading: NetworkImgLayer(
        width: 45,
        height: 45,
        type: ImageType.avatar,
        src: item.face,
      ),
      title: Text(
        item.name,
        maxLines: 1,
        overflow: .ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        item.sign?.isNotEmpty == true ? item.sign! : 'UID: ${item.mid}',
        maxLines: 1,
        overflow: .ellipsis,
        style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
      ),
      trailing: TextButton(
        onPressed: () => showConfirmDialog(
          context: context,
          title: Text('确定取消关注 ${item.name}？'),
          onConfirm: () {
            LocalLibrary.unfollow(item.mid);
          },
        ),
        child: const Text('已关注'),
      ),
    );
  }
}
