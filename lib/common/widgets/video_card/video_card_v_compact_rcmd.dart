import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/image/image_save.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_v.dart'
    show pushRcmdDetail;
import 'package:PiliPlus/common/widgets/video_popup_menu.dart';
import 'package:PiliPlus/models/common/stat_type.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/num_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:material_ui/material_ui.dart';

/// 推荐页专用紧凑卡片：布局与 VideoCardVCompact 一致
/// （播放量在封面左下角、不显示弹幕数、内容区仅标题与 UP），
/// 同时保留推荐数据原有的 goto 跳转与 av 三点菜单。
/// 独立成类，不修改公共 VideoCardV / VideoCardVCompact。
class VideoCardVCompactRcmd extends StatelessWidget {
  final BaseRcmdVideoItemModel videoItem;
  final VoidCallback? onRemove;

  const VideoCardVCompactRcmd({
    super.key,
    required this.videoItem,
    this.onRemove,
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
            onTap: () => pushRcmdDetail(videoItem),
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
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          NetworkImgLayer(
                            src: videoItem.cover,
                            width: maxWidth,
                            height: maxHeight,
                            borderRadius: const .vertical(top: .circular(12)),
                          ),
                          // 播放量：封面内左下角
                          _CoverBadge(
                            left: 7,
                            bottom: 6,
                            type: StatType.play,
                            value: videoItem.stat.view,
                          ),
                          if (videoItem.duration > 0)
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
        if (videoItem.goto == 'av')
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
  final double? bottom;

  const _CoverBadge({
    required this.type,
    required this.value,
    this.left,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
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
