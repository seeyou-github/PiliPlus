import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_h.dart'
    show pushVideoH;
import 'package:PiliPlus/common/widgets/video_card/video_card_v_compact.dart';
import 'package:PiliPlus/models/common/nav_bar_config.dart'
    show NavigationBarType;
import 'package:PiliPlus/pages/dynamics_local/controller.dart';
import 'package:PiliPlus/pages/dynamics_local/widgets/local_up_rail.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/local_feed_cache.dart';
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
  final controller = Get.putOrFind(LocalFeedController.new);

  Worker? _tabWorker;

  @override
  void initState() {
    super.initState();
    // 页面会被 keepAlive，从其它 tab 切回动态页时再刷新一次投稿与直播状态
    if (Get.isRegistered<MainController>()) {
      final mainController = Get.find<MainController>();
      final dynIndex = mainController.navigationBars.indexOf(
        NavigationBarType.dynamics,
      );
      if (dynIndex != -1) {
        _tabWorker = ever<int>(mainController.selectedIndex, (value) {
          if (value == dynIndex) controller.onRefresh();
        });
      }
    }
  }

  @override
  void dispose() {
    _tabWorker?.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;
    final feed = refreshIndicator(
      key: controller.refreshKey,
      onRefresh: controller.onRefresh,
      child: Obx(() {
        final dayGroups = controller.feedDays;
        // 在 Obx 内同步读取 newKeys，列表项的 itemBuilder 在布局阶段执行，
        // 那时读取不会被追踪，会导致点击播放后「新视频」标签无法及时消失
        final newKeys = Set<String>.of(controller.newKeys);
        return CustomScrollView(
          controller: controller.scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (controller.loading.value)
              SliverPadding(
                padding: const .all(Style.safeSpace),
                sliver: gridSkeleton,
              )
            else if (dayGroups.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _Empty(
                  hasFollow: LocalLibrary.follows.isNotEmpty,
                  filtered: controller.filteredMid.value != null,
                ),
              )
            else ...[
              for (var i = 0; i < dayGroups.length; i++) ...[
                SliverToBoxAdapter(
                  child: _DayHeader(label: dayGroups[i].label),
                ),
                SliverPadding(
                  padding: const .fromLTRB(
                    Style.safeSpace,
                    0,
                    Style.safeSpace,
                    Style.cardSpace,
                  ),
                  sliver: SliverGrid.builder(
                    gridDelegate: gridDelegate,
                    itemCount: dayGroups[i].items.length,
                    itemBuilder: (context, index) {
                      if (i == dayGroups.length - 1 &&
                          index == dayGroups[i].items.length - 1) {
                        controller.onLoadMore();
                      }
                      final item = dayGroups[i].items[index];
                      return VideoCardVCompact(
                        videoItem: item,
                        isNew: newKeys.contains(LocalFeedCache.keyOf(item)),
                        onTap: () {
                          controller.markNewRead(item);
                          pushVideoH(item);
                        },
                      );
                    },
                  ),
                ),
              ],
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
        );
      }),
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
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .end,
            children: [
              Obx(
                () => !controller.showBackToTop.value
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const .only(bottom: 12),
                        child: FloatingActionButton.small(
                          heroTag: null,
                          tooltip: '回到顶部',
                          onPressed: controller.animateToTop,
                          backgroundColor: colorScheme.secondaryContainer,
                          foregroundColor: colorScheme.onSecondaryContainer,
                          child: const Icon(Icons.arrow_upward),
                        ),
                      ),
              ),
              FloatingActionButton(
                tooltip: '刷新',
                onPressed: controller.toTopAndRefresh,
                backgroundColor: colorScheme.secondaryContainer,
                foregroundColor: colorScheme.onSecondaryContainer,
                child: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
      );
    }
    return body;
  }
}

class _DayHeader extends StatelessWidget {
  final String label;

  const _DayHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const .fromLTRB(Style.safeSpace, 12, Style.safeSpace, 6),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              height: 1,
              color: colorScheme.outline.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final bool hasFollow;
  final bool filtered;

  const _Empty({required this.hasFollow, required this.filtered});

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
              hasFollow ? (filtered ? '该 UP 暂无投稿' : '关注的 UP 暂无投稿') : '还没有本地关注',
              style: TextStyle(color: theme.colorScheme.outline),
            ),
            Text(
              hasFollow
                  ? (filtered ? '再次点击头像可取消筛选' : '下拉可刷新')
                  : '未登录时在播放页或 UP 主页点击「关注」，这里会汇总他们最新的投稿',
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
