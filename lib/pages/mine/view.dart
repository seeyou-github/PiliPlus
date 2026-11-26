import 'dart:async';

import 'package:PiliPlus/common/assets.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/custom_icon.dart';
import 'package:PiliPlus/common/widgets/flutter/list_tile.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/player_bar.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/mine_tab_type.dart';
import 'package:PiliPlus/models/common/nav_bar_config.dart';
import 'package:PiliPlus/pages/common/common_page.dart';
import 'package:PiliPlus/pages/home/view.dart';
import 'package:PiliPlus/pages/login/controller.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/pages/mine/widgets/fav_item.dart';
import 'package:PiliPlus/pages/mine/widgets/history_item.dart';
import 'package:PiliPlus/pages/mine/widgets/later_item.dart';
import 'package:PiliPlus/pages/mine/widgets/sub_item.dart';
import 'package:PiliPlus/pages/webdav/widgets/sync_now_button.dart';
import 'package:PiliPlus/utils/bili_utils.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/local_library.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart' hide ListTile;

/// 「我的」页顶部功能按钮
typedef _MineAction = ({IconData icon, String title, VoidCallback onTap});

class MinePage extends StatefulWidget {
  const MinePage({super.key, this.showBackBtn = false});

  final bool showBackBtn;

  @override
  State<MinePage> createState() => _MediaPageState();
}

class _MediaPageState extends CommonPageState<MinePage>
    with AutomaticKeepAliveClientMixin {
  final MineController controller = Get.putOrFind(MineController.new);
  late final MainController _mainController = Get.find<MainController>();
  late ThemeData theme;

  @override
  bool get wantKeepAlive => true;

  bool get checkPage =>
      _mainController.navigationBars[0] != NavigationBarType.mine &&
      _mainController.selectedIndex.value == 0;

  @override
  bool onNotificationType1(UserScrollNotification notification) {
    if (checkPage) {
      return false;
    }
    return super.onNotificationType1(notification);
  }

  @override
  bool onNotificationType2(ScrollNotification notification) {
    if (checkPage) {
      return false;
    }
    return super.onNotificationType2(notification);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    theme = Theme.of(context);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final secondary = theme.colorScheme.secondary;
    return Column(
      children: [
        Padding(
          padding: const .symmetric(vertical: 10),
          child: _buildHeaderActions,
        ),
        Expanded(
          child: Material(
            type: .transparency,
            child: refreshIndicator(
              onRefresh: controller.onRefresh,
              child: onBuild(
                ListView(
                  padding: const .only(bottom: 150),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _buildUserInfo(theme, secondary),
                    _buildActions(secondary),
                    for (final tab in controller.mineTabs)
                      switch (tab) {
                        .favorite => Obx(_buildFav),
                        .history => Obx(_buildHistory),
                        .later => Obx(_buildLater),
                        .sub => Obx(_buildSub),
                      },
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(Color primary) {
    return Obx(() {
      final isLogin = controller.accountService.isLogin.value;
      // 未登录时把「观看记录 / 我的订阅 / 稍后再看」换成对应的本地入口，
      // 位置、图标按钮样式与登录态完全一致
      final actions = <_MineAction>[];
      for (final e in controller.list) {
        actions.add(
          isLogin
              ? e
              : switch (e.title) {
                  '观看记录' => _localHistoryAction,
                  '我的订阅' => _localFavAction,
                  '稍后再看' => _localLaterAction,
                  _ => e,
                },
        );
      }
      return Row(
        mainAxisAlignment: .spaceEvenly,
        children: actions
            .map(
              (e) => Flexible(
                child: InkWell(
                  onTap: e.onTap,
                  borderRadius: Style.mdRadius,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 80),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Column(
                        spacing: 6,
                        mainAxisSize: .min,
                        mainAxisAlignment: .center,
                        children: [
                          Icon(e.icon, color: primary),
                          Text(
                            e.title,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      );
    });
  }

  /// 未登录时替换登录态按钮的本地入口
  _MineAction _localAction(IconData icon, String title, String route) =>
      (icon: icon, title: title, onTap: () => Get.toNamed(route));

  /// 本地收藏：占登录态「我的订阅」的位置
  _MineAction get _localFavAction =>
      _localAction(CustomIcons.star_favorite_line, '本地收藏', '/localFav');

  /// 本地观看记录：占登录态「观看记录」的位置
  _MineAction get _localHistoryAction =>
      _localAction(CustomIcons.history, '观看记录', '/localHistory');

  /// 本地稍后再看：占登录态「稍后再看」的位置
  _MineAction get _localLaterAction =>
      _localAction(CustomIcons.watch_later_outlined, '稍后再看', '/localLater');

  Widget get _buildHeaderActions {
    const iconSize = 22.0;
    const padding = EdgeInsets.all(8);
    const style = ButtonStyle(tapTargetSize: .shrinkWrap);
    return PlayerBar(
      left: widget.showBackBtn
          ? const Padding(
              padding: EdgeInsets.only(left: 8),
              child: BackButton(),
            )
          : const SizedBox.shrink(),
      right: Row(
        spacing: 5,
        mainAxisSize: .min,
        children: [
          if (!_mainController.hasHome) ...[
            IconButton(
              iconSize: iconSize,
              padding: padding,
              style: style,
              tooltip: '搜索',
              onPressed: () => Get.toNamed('/search'),
              icon: const Icon(Icons.search),
            ),
            msgBadge(_mainController),
          ],
          if (GStorage.reply != null)
            IconButton(
              iconSize: iconSize,
              padding: padding,
              style: style,
              tooltip: '评论记录',
              onPressed: () => Get.toNamed('/myReply'),
              icon: const Icon(Icons.message_outlined),
            ),
          Obx(
            () {
              if (!controller.accountService.isLogin.value) {
                return const SizedBox.shrink();
              }
              final anonymity = MineController.anonymity.value;
              return IconButton(
                iconSize: iconSize,
                padding: padding,
                style: style,
                tooltip: "${anonymity ? '退出' : '进入'}无痕模式",
                onPressed: MineController.onChangeAnonymity,
                icon: anonymity
                    ? const Icon(MdiIcons.incognito)
                    : const Icon(MdiIcons.incognitoOff),
              );
            },
          ),
          const WebDavSyncNowIconButton(),
          IconButton(
            iconSize: iconSize,
            padding: padding,
            style: style,
            tooltip: '切换账号',
            onPressed: () => LoginPageController.switchAccountDialog(context),
            icon: const Icon(Icons.switch_account_outlined),
          ),
          Obx(
            () => IconButton(
              iconSize: iconSize,
              padding: padding,
              style: style,
              tooltip: '切换至${controller.nextThemeType.label}主题',
              onPressed: controller.onChangeTheme,
              icon: controller.themeType.value.icon,
            ),
          ),
          IconButton(
            iconSize: iconSize,
            padding: padding,
            style: style,
            tooltip: '设置',
            onPressed: () => Get.toNamed('/setting', preventDuplicates: false),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildUserInfo(ThemeData theme, Color secondary) {
    final style = TextStyle(
      fontSize: theme.textTheme.titleMedium!.fontSize,
      fontWeight: FontWeight.bold,
    );
    final labelStyle = theme.textTheme.labelMedium!.copyWith(
      color: theme.colorScheme.outline,
    );
    final coinLabelStyle = TextStyle(
      fontSize: theme.textTheme.labelMedium!.fontSize,
      color: theme.colorScheme.outline,
    );
    final coinValStyle = TextStyle(
      fontSize: theme.textTheme.labelMedium!.fontSize,
      fontWeight: FontWeight.bold,
      color: secondary,
    );
    return Obx(() {
      final userInfo = controller.userInfo.value;
      final levelInfo = userInfo.levelInfo;
      final hasLevel = levelInfo != null;
      final isVip = userInfo.vipStatus != null && userInfo.vipStatus! > 0;
      final userStat = controller.userStat.value;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: .opaque,
            onTap: controller.onLogin,
            onLongPress: () {
              Feedback.forLongPress(context);
              controller.onLogin(true);
            },
            onSecondaryTap: PlatformUtils.isMobile
                ? null
                : () => controller.onLogin(true),
            child: Row(
              mainAxisSize: .min,
              children: [
                const SizedBox(width: 20),
                userInfo.face != null
                    ? Stack(
                        clipBehavior: .none,
                        children: [
                          NetworkImgLayer(
                            src: userInfo.face,
                            type: .avatar,
                            width: 55,
                            height: 55,
                          ),
                          if (isVip)
                            Positioned(
                              right: -1,
                              bottom: -2,
                              child: SvgPicture.asset(
                                Assets.vipIcon,
                                height: 19,
                                semanticsLabel: "大会员",
                              ),
                            ),
                        ],
                      )
                    : ClipOval(
                        child: Image.asset(
                          width: 55,
                          height: 55,
                          cacheHeight: 55.cacheSize(context),
                          Assets.avatarPlaceHolder,
                          semanticLabel: "默认头像",
                        ),
                      ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: .min,
                    mainAxisAlignment: .center,
                    crossAxisAlignment: .start,
                    children: [
                      Row(
                        spacing: 6,
                        children: [
                          Flexible(
                            child: Text(
                              userInfo.uname ?? '点击登录',
                              style: theme.textTheme.titleMedium!.copyWith(
                                height: 1,
                                color: isVip && userInfo.vipType == 2
                                    ? theme.colorScheme.vipColor
                                    : null,
                              ),
                              maxLines: 1,
                              overflow: .ellipsis,
                            ),
                          ),
                          BiliUtils.levelPicture(
                            levelInfo?.currentLevel ?? 0,
                            isSeniorMember: userInfo.isSeniorMember == 1,
                            height: 10,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '硬币 ',
                              style: coinLabelStyle,
                            ),
                            TextSpan(
                              text: userInfo.money?.toString() ?? '-',
                              style: coinValStyle,
                            ),
                            TextSpan(
                              text: "      经验 ",
                              style: coinLabelStyle,
                            ),
                            TextSpan(
                              text: levelInfo?.currentExp?.toString() ?? '-',
                              style: coinValStyle,
                            ),
                            TextSpan(
                              text: "/${levelInfo?.nextExp ?? '-'}",
                              style: coinLabelStyle,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 225),
                        child: LinearProgressIndicator(
                          minHeight: 2.25,
                          value: hasLevel
                              ? levelInfo.currentExp! / levelInfo.nextExp!
                              : 0,
                          backgroundColor: theme.colorScheme.outline.withValues(
                            alpha: 0.4,
                          ),
                          valueColor: AlwaysStoppedAnimation<Color>(secondary),
                          stopIndicatorColor: Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: .spaceEvenly,
            children: [
              _btn(
                count: userStat.dynamicCount,
                countStyle: style,
                name: '动态',
                labelStyle: labelStyle,
                onTap: () => controller.push('memberDynamics'),
              ),
              _btn(
                count: controller.isLogin
                    ? userStat.following
                    : LocalLibrary.followCount.value,
                countStyle: style,
                name: '关注',
                labelStyle: labelStyle,
                onTap: () => controller.isLogin
                    ? controller.push('follow')
                    : Get.toNamed('/localFollow'),
              ),
              _btn(
                count: userStat.follower,
                countStyle: style,
                name: '粉丝',
                labelStyle: labelStyle,
                onTap: () => controller.push('fan'),
              ),
            ],
          ),
        ],
      );
    });
  }

  Widget _btn({
    required int? count,
    required TextStyle countStyle,
    required String name,
    required TextStyle? labelStyle,
    required VoidCallback onTap,
  }) {
    return Flexible(
      child: InkWell(
        onTap: onTap,
        borderRadius: Style.mdRadius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 80),
          child: AspectRatio(
            aspectRatio: 1,
            child: Column(
              spacing: 4,
              mainAxisSize: .min,
              mainAxisAlignment: .center,
              children: [
                Text(
                  count?.toString() ?? '-',
                  style: countStyle,
                ),
                Text(
                  name,
                  style: labelStyle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _autoRefresh(MineRefreshMixin tabCtr) => Timer(
    const Duration(milliseconds: 150),
    () => tabCtr.onRefresh(isManual: false),
  );

  Widget _buildFav() {
    // 未登录时本地收藏入口已移到上方功能按钮区（原「我的订阅」位置）
    if (!controller.isLogin) {
      return const SizedBox.shrink();
    }
    return _buildTab(
      .favorite,
      controller.favCtr!,
      itemBuilder: (element) => FavFolderItem(
        item: element,
        onPop: () => _autoRefresh(controller.favCtr!),
      ),
      onPushDetail: () => Get.toNamed(
        '/fav',
      )?.whenComplete(() => _autoRefresh(controller.favCtr!)),
    );
  }

  Widget _buildHistory() {
    // 未登录时「观看记录」入口已移到上方功能按钮区
    if (!controller.isLogin) {
      return const SizedBox.shrink();
    }
    return _buildTab(
      .history,
      controller.historyCtr!,
      itemBuilder: (element) => MineHistoryItem(
        item: element,
        onPop: () => _autoRefresh(controller.historyCtr!),
      ),
      onPushDetail: () => Get.toNamed(
        '/history',
      )?.whenComplete(() => _autoRefresh(controller.historyCtr!)),
    );
  }

  Widget _buildLater() {
    // 未登录时「稍后再看」入口已移到上方功能按钮区
    if (!controller.isLogin) {
      return const SizedBox.shrink();
    }
    return _buildTab(
      .later,
      controller.laterCtr!,
      itemBuilder: (element) => MineLaterItem(
        item: element,
        onPop: () => _autoRefresh(controller.laterCtr!),
      ),
      onPushDetail: () => Get.toNamed(
        '/later',
      )?.whenComplete(() => _autoRefresh(controller.laterCtr!)),
    );
  }

  Widget _buildSub() {
    return _buildTab(
      .sub,
      controller.subCtr!,
      itemBuilder: (element) => MineSubItem(
        item: element,
        onPop: () => _autoRefresh(controller.subCtr!),
      ),
      onPushDetail: () => Get.toNamed(
        '/subscription',
      )?.whenComplete(() => _autoRefresh(controller.subCtr!)),
    );
  }

  Widget _buildTab<R, T>(
    MineTabType tab,
    MineRefreshMixin<R, T> tabCtr, {
    required Widget Function(T element) itemBuilder,
    required VoidCallback onPushDetail,
  }) {
    final Widget child;
    switch (tabCtr.loadingState.value) {
      case Loading():
        return const SizedBox.shrink();
      case Success(:final response):
        if (response == null || response.isEmpty) {
          return const SizedBox.shrink();
        }
        child = SizedBox(
          height: 180,
          child: ListView.separated(
            itemCount: response.length,
            controller: tabCtr.scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const .only(left: 20, top: 10, right: 20),
            itemBuilder: (context, index) {
              if (index == response.length - 1) {
                tabCtr.onLoadMore();
              }
              return SizedBox(width: 180, child: itemBuilder(response[index]));
            },
            scrollDirection: .horizontal,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
          ),
        );
      case Error(:final errMsg):
        if (errMsg == null) return const SizedBox.shrink();
        child = SizedBox(
          height: 160,
          child: Center(child: Text(errMsg, textAlign: .center)),
        );
    }
    final secondary = theme.colorScheme.secondary;
    return Column(
      children: [
        Divider(
          height: 20,
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
        ListTile(
          dense: true,
          onTap: onPushDetail,
          title: Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${tab.label}  ',
                    style: const TextStyle(fontSize: 16, fontWeight: .bold),
                  ),
                  if (tabCtr.count != null)
                    TextSpan(
                      text: '${tabCtr.count}  ',
                      style: TextStyle(color: secondary),
                    ),
                  WidgetSpan(
                    child: Icon(
                      Icons.arrow_forward_ios,
                      size: 18,
                      color: secondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          trailing: IconButton(
            tooltip: '刷新',
            onPressed: tabCtr.onRefresh,
            icon: const Icon(Icons.refresh, size: 20),
          ),
        ),
        child,
      ],
    );
  }
}
