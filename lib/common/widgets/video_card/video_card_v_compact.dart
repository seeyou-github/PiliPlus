import 'package:PiliPlus/common/skeleton/video_card_v.dart';
import 'package:PiliPlus/common/sliver_single_child_delegate.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/image/image_save.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/progress_bar/video_progress_indicator.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_h.dart'
    show pushVideoH;
import 'package:PiliPlus/common/widgets/video_popup_menu.dart';
import 'package:PiliPlus/models/common/stat_type.dart';
import 'package:PiliPlus/models/horizontal_video_model.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/num_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:material_ui/material_ui.dart';

/// 视频卡片 - 垂直布局（紧凑版）
///
/// 与 [VideoCardV] 的差异：
/// - 播放量移到封面左下角（圆角半透明底，与时长徽章一致）
/// - 不显示弹幕数
/// - 内容区去掉统计行，卡片更矮，UP名称相应上移
///
/// 独立成类，不修改 VideoCardV，避免影响推荐页等已有列表
class VideoCardVCompact extends StatelessWidget {
  final HorizontalVideoModel videoItem;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final bool isNew;

  const VideoCardVCompact({
    super.key,
    required this.videoItem,
    this.onTap,
    this.onRemove,
    this.isNew = false,
  });

  void onLongPress() => imageSaveDialog(
    bvid: videoItem.bvid,
    title: videoItem.title,
    cover: videoItem.cover,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Card(
          child: InkWell(
            onTap: onTap ?? () => pushVideoH(videoItem),
            onLongPress: onLongPress,
            onSecondaryTap: PlatformUtils.isMobile ? null : onLongPress,
            borderRadius: const .all(.circular(12)),
            child: Column(
              crossAxisAlignment: .start,
              children: [
                AspectRatio(
                  aspectRatio: Style.aspectRatio,
                  child: LayoutBuilder(
                    builder: (context, boxConstraints) {
                      final double maxWidth = boxConstraints.maxWidth;
                      final double maxHeight = boxConstraints.maxHeight;
                      final progress = videoItem.progress;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          NetworkImgLayer(
                            src: videoItem.cover,
                            width: maxWidth,
                            height: maxHeight,
                            borderRadius: const .vertical(top: .circular(12)),
                          ),
                          if (videoItem.badge case final badge?)
                            PBadge(
                              text: badge,
                              top: 6,
                              left: isNew ? 6 : null,
                              right: isNew ? null : 6,
                              type: switch (badge) {
                                '充电专属' => .error,
                                _ => .primary,
                              },
                            ),
                          if (isNew)
                            const PBadge(
                              text: '新视频',
                              top: 6,
                              right: 6,
                              type: .error,
                            ),
                          // 播放量：封面内左下角
                          if (videoItem.isLive != true)
                            _CoverBadge(
                              left: 7,
                              bottom: 6,
                              type: StatType.play,
                              value: videoItem.stat.view,
                            ),
                          if (progress != null && progress != 0) ...[
                            PBadge(
                              text: progress == -1
                                  ? '已看完'
                                  : '${DurationUtils.formatDuration(progress)}/${DurationUtils.formatDuration(videoItem.duration)}',
                              right: 7,
                              bottom: 6,
                              type: .gray,
                            ),
                            Positioned(
                              left: 0,
                              bottom: 0,
                              right: 0,
                              child: VideoProgressIndicator(
                                color: theme.colorScheme.primary,
                                backgroundColor:
                                    theme.colorScheme.secondaryContainer,
                                progress: progress == -1
                                    ? 1
                                    : progress / videoItem.duration,
                              ),
                            ),
                          ] else if (videoItem.duration > 0)
                            PBadge(
                              text: DurationUtils.formatDuration(
                                videoItem.duration,
                              ),
                              right: 7,
                              bottom: 6,
                              type: .gray,
                            ),
                        ],
                      );
                    },
                  ),
                ),
                content(theme),
              ],
            ),
          ),
        ),
        Positioned(
          right: -5,
          bottom: -2,
          width: 29,
          height: 29,
          child: VideoPopupMenu(
            iconSize: 17,
            videoItem: videoItem,
            onRemove: onRemove,
          ),
        ),
      ],
    );
  }

  Widget content(ThemeData theme) {
    return Expanded(
      child: Padding(
        padding: const .fromLTRB(6, 5, 6, 5),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Expanded(
              child: Text(
                videoItem.title,
                maxLines: 2,
                overflow: .ellipsis,
                style: const TextStyle(height: 1.38),
              ),
            ),
            Padding(
              padding: const .only(right: 18),
              child: Text(
                videoItem.owner.name.toString(),
                maxLines: 1,
                overflow: .ellipsis,
                semanticsLabel: 'UP：${videoItem.owner.name}',
                style: TextStyle(
                  height: 1.5,
                  fontSize: theme.textTheme.labelMedium!.fontSize,
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 封面内的统计徽章（播放量），与时长徽章样式保持一致
class _CoverBadge extends StatelessWidget {
  final StatType type;
  final dynamic value;
  final double? left;
  final double? right;
  final double? top;
  final double? bottom;

  const _CoverBadge({
    required this.type,
    required this.value,
    this.left,
    this.right,
    this.top,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: Container(
        padding: const .symmetric(horizontal: 4, vertical: 2),
        decoration: const BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.all(Radius.circular(3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 2,
          children: [
            Icon(type.iconData, size: 11, color: Colors.white),
            Text(
              NumUtils.numFormat(value),
              style: const TextStyle(
                fontSize: 11,
                height: 1,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 紧凑垂直卡片的网格布局（内容区高度比推荐页更小）
mixin VideoCardVCompactGridMixin<T extends StatefulWidget> on State<T> {
  late final gridDelegate = SliverGridDelegateWithExtentAndRatio(
    mainAxisSpacing: Style.cardSpace,
    crossAxisSpacing: Style.cardSpace,
    maxCrossAxisExtent: Pref.recommendCardWidth,
    childAspectRatio: Style.aspectRatio,
    mainAxisExtent: MediaQuery.textScalerOf(context).scale(68),
  );

  Widget get gridSkeleton => SliverGrid(
    gridDelegate: gridDelegate,
    delegate: const SliverSingleChildDelegate(
      count: 10,
      child: VideoCardVSkeleton(),
    ),
  );
}
