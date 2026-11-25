import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/models/common/image_type.dart';
import 'package:PiliPlus/models/local/local_follow_item.dart';
import 'package:PiliPlus/models/member/info.dart' show LiveRoom;
import 'package:PiliPlus/pages/dynamics_local/controller.dart';
import 'package:PiliPlus/utils/local_library.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// 本地关注 UP 左侧竖列：直播分类在上，关注列表在下，管理按钮固定在底部。
/// 正在直播的 UP 会同时出现在直播分组与关注分组中；
/// 关注分组里点击头像筛选该 UP 的投稿，长按进入 UP 主页。
class LocalUpRail extends StatelessWidget {
  final LocalFeedController controller;

  const LocalUpRail({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      // 关注数变化后即时刷新列表；角标与置顶顺序由 Rx 状态驱动
      final count = LocalLibrary.followCount.value;
      final follows = LocalLibrary.follows;
      final rooms = controller.liveRooms.value;
      final updates = controller.updateCounts;
      final pinned = controller.updatedMids;
      final selected = controller.filteredMid.value;

      final liveFollows = follows
          .where((e) => rooms.containsKey(e.mid))
          .toList();
      final normalFollows = follows.toList()
        ..sort((a, b) {
          // 有新增投稿的 UP 置顶，其余按未读数量、关注时间排序
          final byPinned = (pinned.contains(b.mid) ? 1 : 0)
              .compareTo(pinned.contains(a.mid) ? 1 : 0);
          if (byPinned != 0) return byPinned;
          final byUpdate = (updates[b.mid] ?? 0).compareTo(updates[a.mid] ?? 0);
          if (byUpdate != 0) return byUpdate;
          return b.addTime.compareTo(a.addTime);
        });

      return Column(
        children: [
          Expanded(
            child: ListView(
              padding: const .only(bottom: 8),
              children: [
                if (liveFollows.isNotEmpty) ...[
                  _RailLabel('直播', color: theme.colorScheme.error),
                  for (final item in liveFollows)
                    _LiveTile(item: item, room: rooms[item.mid]!),
                  const SizedBox(height: 12),
                ],
                _RailLabel('关注', color: theme.colorScheme.outline),
                for (final item in normalFollows)
                  _UpTile(
                    item: item,
                    count: updates[item.mid] ?? 0,
                    selected: selected == item.mid,
                    onTap: () => controller.toggleFilter(item.mid),
                  ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: theme.colorScheme.outline.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 8),
          _ManageTile(count: count),
          SizedBox(height: PlatformUtils.isMobile ? 80 : 12),
        ],
      );
    });
  }
}

class _RailLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _RailLabel(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .fromLTRB(8, 10, 8, 4),
      child: Text(
        text,
        textAlign: .center,
        style: TextStyle(fontSize: 11, color: color),
      ),
    );
  }
}

class _UpTile extends StatelessWidget {
  final LocalFollowItem item;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _UpTile({
    required this.item,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: '点击筛选，长按进入 UP 主页',
      waitDuration: const Duration(seconds: 1),
      child: InkWell(
        onTap: onTap,
        onLongPress: () => Get.toNamed('/member?mid=${item.mid}'),
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: .min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  NetworkImgLayer(
                    width: 46,
                    height: 46,
                    type: ImageType.avatar,
                    src: item.face,
                  ),
                  if (selected)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (count > 0)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        padding: const .symmetric(horizontal: 3, vertical: 1),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          borderRadius: .all(.circular(8)),
                        ),
                        child: Text(
                          '$count',
                          textAlign: .center,
                          style: const TextStyle(
                            fontSize: 10,
                            height: 1.2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item.name,
                maxLines: 1,
                overflow: .ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : null,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveTile extends StatelessWidget {
  final LocalFollowItem item;
  final LiveRoom room;

  const _LiveTile({required this.item, required this.room});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => PageUtils.toLiveRoom(room.roomId),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: .min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                NetworkImgLayer(
                  width: 46,
                  height: 46,
                  type: ImageType.avatar,
                  src: item.face,
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: -4,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      borderRadius: .all(.circular(6)),
                    ),
                    child: const Text(
                      '直播',
                      textAlign: .center,
                      style: TextStyle(fontSize: 9, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.name,
              maxLines: 1,
              overflow: .ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManageTile extends StatelessWidget {
  final int count;

  const _ManageTile({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => Get.toNamed('/localFollow'),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: .min,
          children: [
            CircleAvatar(
              radius: 23,
              backgroundColor: theme.colorScheme.secondaryContainer,
              child: Icon(
                Icons.person_add_alt_1_outlined,
                size: 20,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '管理($count)',
              maxLines: 1,
              overflow: .ellipsis,
              style: TextStyle(fontSize: 11, color: theme.colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
