import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/image/image_save.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/models_new/live/live_feed_index/card_data_list_item.dart';
import 'package:PiliPlus/pages/live/widgets/live_popup_menu.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:material_ui/material_ui.dart';

// 视频卡片 - 垂直布局
class LiveCardVApp extends StatelessWidget {
  final CardLiveItem item;
  final bool showFirstFrame;
  final VoidCallback? onRemove;

  const LiveCardVApp({
    super.key,
    required this.item,
    this.showFirstFrame = false,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    void onLongPress() => imageSaveDialog(
      title: item.title,
      cover: showFirstFrame ? item.systemCover : item.cover,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Card(
          child: InkWell(
            onTap: () => PageUtils.toLiveRoom(item.roomid),
            onLongPress: onLongPress,
            onSecondaryTap: PlatformUtils.isMobile ? null : onLongPress,
            borderRadius: const .all(.circular(12)),
            child: Column(
              crossAxisAlignment: .start,
              children: [
                AspectRatio(
                  aspectRatio: Style.aspectRatio,
                  child: LayoutBuilder(
                    builder: (context, boxConstraints) => Stack(
                      clipBehavior: Clip.none,
                      children: [
                        NetworkImgLayer(
                          src: showFirstFrame ? item.systemCover : item.cover,
                          width: boxConstraints.maxWidth,
                          height: boxConstraints.maxHeight,
                          borderRadius: const .vertical(top: .circular(12)),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: videoStat(),
                        ),
                      ],
                    ),
                  ),
                ),
                liveContent(theme),
              ],
            ),
          ),
        ),
        Positioned(
          right: -5,
          bottom: -2,
          width: 29,
          height: 29,
          child: LivePopupMenu(
            iconSize: 17,
            uid: item.uid,
            uname: item.uname,
            roomid: item.roomid,
            feedback: item.feedback,
            onRemove: onRemove,
          ),
        ),
      ],
    );
  }

  Widget liveContent(ThemeData theme) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                item.title.toString(),
                textAlign: TextAlign.start,
                style: const TextStyle(height: 1.38, letterSpacing: 0.3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Text(
                item.uname.toString(),
                textAlign: TextAlign.start,
                style: TextStyle(
                  height: 1.5,
                  fontSize: theme.textTheme.labelMedium!.fontSize,
                  color: theme.colorScheme.outline,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget videoStat() {
    return Container(
      height: 50,
      padding: const EdgeInsets.only(top: 26, left: 10, right: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Colors.transparent, Colors.black54],
          tileMode: TileMode.mirror,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            item.areaName.toString(),
            style: const TextStyle(fontSize: 11, color: Colors.white),
          ),
          if (item.watchedShow?.textLarge case final textLarge?)
            Text(
              textLarge,
              style: const TextStyle(fontSize: 11, color: Colors.white),
            ),
        ],
      ),
    );
  }
}
