import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_v_compact.dart';
import 'package:PiliPlus/models/common/image_type.dart';
import 'package:PiliPlus/pages/dynamics_local/controller.dart';
import 'package:PiliPlus/utils/local_library.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// 未登录时的动态页：本地关注 UP 的投稿流
class LocalFeedPage extends StatefulWidget {
  const LocalFeedPage({super.key});

  @override
  State<LocalFeedPage> createState() => _LocalFeedPageState();
}

class _LocalFeedPageState extends State<LocalFeedPage>
    with AutomaticKeepAliveClientMixin, VideoCardVCompactGridMixin {
  final controller = Get.put(LocalFeedController());

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return refreshIndicator(
      onRefresh: controller.onRefresh,
      child: Obx(
        () => CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 本地关注 UP 列表
            SliverToBoxAdapter(
              child: SizedBox(
                height: 78,
                child: Obx(() {
                  // 监听关注数，新增/取消关注后即时刷新
                  final count = LocalLibrary.followCount.value;
                  final follows = LocalLibrary.follows;
                  return ListView.builder(
                    scrollDirection: .horizontal,
                    padding: const .symmetric(horizontal: Style.safeSpace),
                    itemCount: follows.length + 1,
                    itemBuilder: (context, index) {
                      if (index == follows.length) {
                        return _ManageTile(count: count);
                      }
                      final item = follows[index];
                      return Padding(
                        padding: const .only(right: 12),
                        child: GestureDetector(
                          onTap: () => Get.toNamed('/member?mid=${item.mid}'),
                          child: SizedBox(
                            width: 56,
                            child: Column(
                              mainAxisSize: .min,
                              children: [
                                NetworkImgLayer(
                                  width: 46,
                                  height: 46,
                                  type: ImageType.avatar,
                                  src: item.face,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.name,
                                  maxLines: 1,
                                  overflow: .ellipsis,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ),
            if (controller.loading.value)
              SliverPadding(
                padding: const .all(Style.safeSpace),
                sliver: gridSkeleton,
              )
            else if (controller.items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _Empty(hasFollow: LocalLibrary.follows.isNotEmpty),
              )
            else ...[
              SliverPadding(
                padding: const .fromLTRB(
                  Style.safeSpace,
                  Style.cardSpace,
                  Style.safeSpace,
                  Style.cardSpace,
                ),
                sliver: SliverGrid.builder(
                  gridDelegate: gridDelegate,
                  itemBuilder: (context, index) {
                    if (index == controller.items.length - 1) {
                      controller.onLoadMore();
                    }
                    return VideoCardVCompact(
                      videoItem: controller.items[index],
                    );
                  },
                  itemCount: controller.items.length,
                ),
              ),
              if (!controller.isEnd.value)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: .symmetric(vertical: 12),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
              const SliverPadding(padding: .only(bottom: 100)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final bool hasFollow;

  const _Empty({required this.hasFollow});

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
              hasFollow ? Icons.video_library_outlined : Icons.person_add_alt,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            Text(
              hasFollow ? '关注的 UP 暂无投稿' : '还没有本地关注',
              style: TextStyle(color: theme.colorScheme.outline),
            ),
            Text(
              hasFollow ? '下拉可刷新' : '未登录时在播放页或 UP 主页点击「关注」，这里会汇总他们最新的投稿',
              textAlign: .center,
              style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
            ),
            if (!hasFollow)
              FilledButton.tonal(
                onPressed: () => Get.toNamed('/localFollow'),
                child: const Text('查看本地关注'),
              ),
          ],
        ),
      ),
    );
  }
}

/// 头像条末尾的「管理」入口
class _ManageTile extends StatelessWidget {
  final int count;

  const _ManageTile({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const .only(right: 12),
      child: GestureDetector(
        onTap: () => Get.toNamed('/localFollow'),
        child: SizedBox(
          width: 56,
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
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
