import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/common/widgets/dialog/export_import.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_h.dart'
    show pushVideoH;
import 'package:PiliPlus/grpc/bilibili/app/listener/v1.pbenum.dart'
    show PlaylistSource;
import 'package:PiliPlus/models/common/dynamic/article_type.dart';
import 'package:PiliPlus/models/local/local_fav_item.dart';
import 'package:PiliPlus/models/model_hot_video_item.dart';
import 'package:PiliPlus/pages/audio/view.dart' show AudioPage;
import 'package:PiliPlus/utils/local_library.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// 本地收藏（未登录时使用）
///
/// 按资源类型分组展示，数据来自 [LocalLibrary]，与在线收藏完全隔离。
class LocalFavPage extends StatelessWidget {
  const LocalFavPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SimpleScaffold(
      appBar: AppBar(
        title: Obx(() => Text('本地收藏 ${LocalLibrary.favCount.value}')),
        actions: [
          IconButton(
            tooltip: '导入/导出本地关注/收藏',
            onPressed: () => showImportExportDialog<Map>(
              context,
              title: '本地关注/收藏',
              localFileName: () => 'local',
              onExport: () =>
                  Utils.jsonEncoder.convert(LocalLibrary.exportJson()),
              onImport: (json) => LocalLibrary.importJson(json),
            ),
            icon: const Icon(Icons.swap_vert),
          ),
          Obx(
            () => LocalLibrary.favCount.value == 0
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: '清空本地收藏',
                    onPressed: () => showConfirmDialog(
                      context: context,
                      title: const Text('确定清空全部本地收藏？'),
                      onConfirm: LocalLibrary.clearFavs,
                    ),
                    icon: const Icon(Icons.delete_sweep_outlined),
                  ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Obx(() {
        // 读取 Rx 计数以注册依赖，否则 Obx 零依赖会抛异常导致 body 空白
        final count = LocalLibrary.favCount.value;
        final favs = LocalLibrary.favs;
        if (count == 0 || favs.isEmpty) {
          return const _Empty();
        }
        final children = <Widget>[];
        for (final type in LocalFavType.values) {
          final list = favs.where((e) => e.type == type).toList();
          if (list.isEmpty) continue;
          children
            ..add(
              Padding(
                padding: const .fromLTRB(16, 14, 16, 6),
                child: Text(
                  '${type.label}（${list.length}）',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            )
            ..addAll(list.map((e) => _FavItemCard(item: e)));
        }
        return ListView(
          padding: const .only(top: 2, bottom: 60),
          children: children,
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
              Icons.star_border_rounded,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            Text('还没有本地收藏', style: TextStyle(color: theme.colorScheme.outline)),
            Text(
              '未登录时点击「收藏」，内容会保存到本地',
              textAlign: .center,
              style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavItemCard extends StatelessWidget {
  final LocalFavItem item;

  const _FavItemCard({required this.item});

  void _onTap() {
    switch (item.type) {
      case LocalFavType.video:
        pushVideoH(
          HotVideoItemModel.fromJson({
            'aid': item.oid,
            'cid': item.subId,
            'title': item.title,
            'pic': item.cover,
            'duration': item.duration,
            'owner': {'name': item.author},
            'stat': const <String, dynamic>{},
          }),
        );
      case LocalFavType.pgc:
        PageUtils.viewPgc(seasonId: item.oid, epId: item.subId);
      case LocalFavType.article:
        Get.toNamed(
          '/articlePage',
          arguments: {'type': ArticleType.read, 'id': '${item.oid}'},
        );
      case LocalFavType.topic:
        Get.toNamed(
          '/dynTopic',
          parameters: {'id': '${item.oid}', 'name': item.title},
        );
      case LocalFavType.season:
        // UGC 合集：按收藏时记录的入口视频 aid 跳转
        pushVideoH(
          HotVideoItemModel.fromJson({
            'aid': item.subId,
            'title': item.title,
            'pic': item.cover,
            'owner': {'name': item.author},
            'stat': const <String, dynamic>{},
          }),
        );
      case LocalFavType.favFolder:
        Get.toNamed(
          '/favDetail',
          parameters: {'mediaId': '${item.oid}', 'heroTag': item.key},
        );
      case LocalFavType.audio:
        AudioPage.toAudioPage(
          itemType: 3,
          id: item.subId,
          oid: item.oid,
          from: PlaylistSource.MEM_SPACE,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: _onTap,
      leading: ClipRRect(
        borderRadius: const .all(.circular(4)),
        child: NetworkImgLayer(
          width: 76,
          height: item.type == LocalFavType.audio ? 76 : 46,
          src: item.cover,
        ),
      ),
      title: Text(
        item.title,
        maxLines: 2,
        overflow: .ellipsis,
        style: const TextStyle(fontSize: 13.5, height: 1.35),
      ),
      subtitle: Text(
        [
          if (item.author?.isNotEmpty == true) item.author!,
          item.type.label,
        ].join(' · '),
        maxLines: 1,
        overflow: .ellipsis,
        style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
      ),
      trailing: IconButton(
        tooltip: '移除',
        onPressed: () => showConfirmDialog(
          context: context,
          title: const Text('确定移出本地收藏？'),
          onConfirm: () => LocalLibrary.removeFavItem(item),
        ),
        icon: Icon(Icons.star_rounded, color: theme.colorScheme.primary),
      ),
    );
  }
}
