import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/models/local/local_later_item.dart';
import 'package:PiliPlus/utils/local_later.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// 本地稍后再看（未登录时使用）
///
/// 数据来自 [LocalLater]，只保存在本机，不参与备份 / 同步 / 导出。
class LocalLaterPage extends StatelessWidget {
  const LocalLaterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SimpleScaffold(
      appBar: AppBar(
        title: const Text('稍后再看'),
        actions: [
          Obx(
            () => LocalLater.count.value == 0
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: '清空稍后再看',
                    onPressed: () => showConfirmDialog(
                      context: context,
                      title: const Text('确定清空本机稍后再看？'),
                      onConfirm: LocalLater.clear,
                    ),
                    icon: const Icon(Icons.delete_sweep_outlined),
                  ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Obx(() {
        // 订阅计数与版本号：增删后列表能刷新
        final count = LocalLater.count.value;
        final _ = LocalLater.revision.value;
        if (count == 0) return const _Empty();
        final items = LocalLater.items;
        return ListView.builder(
          padding: EdgeInsets.only(
            top: 4,
            bottom: MediaQuery.viewPaddingOf(context).bottom + 20,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => _LaterTile(item: items[index]),
        );
      }),
    );
  }
}

class _LaterTile extends StatelessWidget {
  static const double _coverWidth = 140;

  const _LaterTile({required this.item});

  final LocalLaterItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => PageUtils.toVideoPage(
        bvid: item.bvid,
        cid: item.cid,
        title: item.title,
        cover: item.cover,
        extraArguments: const {'viewLater': true},
      ),
      onLongPress: () => showConfirmDialog(
        context: context,
        title: const Text('从稍后再看移除？'),
        onConfirm: () => LocalLater.remove(item.key),
      ),
      child: Padding(
        padding: const .symmetric(
          horizontal: Style.safeSpace,
          vertical: 6,
        ),
        child: Row(
          crossAxisAlignment: .start,
          children: [
            SizedBox(
              width: _coverWidth,
              child: AspectRatio(
                aspectRatio: Style.aspectRatio,
                child: ClipRRect(
                  borderRadius: Style.mdRadius,
                  child: NetworkImgLayer(
                    src: item.cover,
                    width: _coverWidth,
                    height: _coverWidth / Style.aspectRatio,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: _coverWidth / Style.aspectRatio,
                child: Column(
                  crossAxisAlignment: .start,
                  mainAxisAlignment: .spaceBetween,
                  children: [
                    Text(
                      item.title.isEmpty ? '未知标题' : item.title,
                      maxLines: 2,
                      overflow: .ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      [
                        if (item.ownerName?.isNotEmpty == true) item.ownerName!,
                        _timeText(item.addTime),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: .ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 加入时间：今天 / 昨天带时刻，更早显示日期
  static String _timeText(int millis) {
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final hm = '${two(date.hour)}:${two(date.minute)}';
    final dayDiff = DateTime.utc(now.year, now.month, now.day)
        .difference(DateTime.utc(date.year, date.month, date.day))
        .inDays;
    if (dayDiff == 0) return '今天 $hm';
    if (dayDiff == 1) return '昨天 $hm';
    if (date.year == now.year) return '${date.month}月${date.day}日';
    return '${date.year}年${date.month}月${date.day}日';
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
              Icons.watch_later_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            Text(
              '还没有稍后再看',
              style: TextStyle(color: theme.colorScheme.outline),
            ),
            Text(
              '未登录时加入的视频只保存在本机，不会上传也不会同步',
              textAlign: .center,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
