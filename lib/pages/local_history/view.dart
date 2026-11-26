import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/models/local/local_history_item.dart';
import 'package:PiliPlus/utils/local_history.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// 本地观看记录（未登录时使用）
///
/// 数据来自 [LocalHistory]，只保存在本机，不参与备份 / 同步 / 导出。
class LocalHistoryPage extends StatelessWidget {
  const LocalHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SimpleScaffold(
      appBar: AppBar(
        title: const Text('观看记录'),
        actions: [
          Obx(
            () => LocalHistory.count.value == 0
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: '清空观看记录',
                    onPressed: () => showConfirmDialog(
                      context: context,
                      title: const Text('确定清空本机观看记录？'),
                      onConfirm: LocalHistory.clear,
                    ),
                    icon: const Icon(Icons.delete_sweep_outlined),
                  ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Obx(() {
        // 订阅计数与版本号：增删、进度更新后列表都能刷新
        final count = LocalHistory.count.value;
        final _ = LocalHistory.revision.value;
        if (count == 0) return const _Empty();
        final items = LocalHistory.items;
        return ListView.builder(
          padding: EdgeInsets.only(
            top: 4,
            bottom: MediaQuery.viewPaddingOf(context).bottom + 20,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => _HistoryTile(item: items[index]),
        );
      }),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  static const double _coverWidth = 140;

  const _HistoryTile({required this.item});

  final LocalHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final duration = item.duration;
    final progress = item.progress;
    final double ratio = duration > 0 && progress > 0
        ? (progress / (duration * 1000)).clamp(0.0, 1.0).toDouble()
        : 0;
    return InkWell(
      onTap: () => PageUtils.toVideoPage(
        bvid: item.bvid,
        cid: item.cid,
        title: item.title,
        cover: item.cover,
        progress: progress > 0 ? progress : null,
      ),
      onLongPress: () => showConfirmDialog(
        context: context,
        title: const Text('删除这条观看记录？'),
        onConfirm: () => LocalHistory.remove(item.key),
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
                  child: Stack(
                    fit: .expand,
                    children: [
                      NetworkImgLayer(
                        src: item.cover,
                        width: _coverWidth,
                        height: _coverWidth / Style.aspectRatio,
                      ),
                      if (ratio > 0)
                        Align(
                          alignment: .bottomCenter,
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 2,
                            backgroundColor: Colors.black26,
                          ),
                        ),
                    ],
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
                        _timeText(item.watchTime),
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

  /// 观看时间：今天 / 昨天带时刻，更早显示日期
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
              Icons.history,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            Text(
              '还没有观看记录',
              style: TextStyle(color: theme.colorScheme.outline),
            ),
            Text(
              '未登录时看过的视频会记录在本机，不会上传也不会同步',
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
