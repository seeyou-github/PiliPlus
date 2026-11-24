import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_v_compact.dart';
import 'package:PiliPlus/pages/dynamics_local/controller.dart';
import 'package:PiliPlus/pages/dynamics_local/widgets/local_up_rail.dart';
import 'package:PiliPlus/utils/local_library.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
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
    final colorScheme = Theme.of(context).colorScheme;
    final feed = refreshIndicator(
      key: controller.refreshKey,
      onRefresh: controller.onRefresh,
      child: Obx(
        () => CustomScrollView(
          controller: controller.scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
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

    final body = Row(
      crossAxisAlignment: .stretch,
      children: [
        SizedBox(width: 72, child: LocalUpRail(controller: controller)),
        VerticalDivider(
          width: 1,
          color: colorScheme.outline.withValues(alpha: 0.1),
        ),
        Expanded(child: feed),
      ],
    );

    if (PlatformUtils.isDesktop && Pref.showRefreshFAB) {
      return ScaffoldLayout(
        body: body,
        fab: Padding(
          padding: const .only(
            right: kFloatingActionButtonMargin,
            bottom: 80 + kFloatingActionButtonMargin,
          ),
          child: FloatingActionButton(
            tooltip: '刷新',
            onPressed: controller.toTopAndRefresh,
            backgroundColor: colorScheme.secondaryContainer,
            foregroundColor: colorScheme.onSecondaryContainer,
            child: const Icon(Icons.refresh),
          ),
        ),
      );
    }
    return body;
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
