import 'package:PiliPlus/common/widgets/custom_icon.dart';
import 'package:PiliPlus/http/live.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models_new/live/live_feed_index/feedback.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/pages/search/widgets/search_text.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/local_blacklist.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart' hide Feedback;

class _LiveCustomAction {
  final String title;
  final Widget icon;
  final VoidCallback onTap;
  const _LiveCustomAction(this.title, this.icon, this.onTap);
}

/// 直播卡片右下角的更多菜单
///
/// 与推荐页卡片的 [VideoPopupMenu] 保持一致：同样的入口样式、同样的 45 高度菜单项，
/// 支持访问 UP、不感兴趣（直播反馈）、拉黑用户（本地/在线）、无痕模式。
///
/// 独立成类，不修改 [VideoPopupMenu]，避免影响视频卡片。
class LivePopupMenu extends StatelessWidget {
  /// UP 主 mid
  final int? uid;

  /// UP 主昵称
  final String? uname;

  /// 直播间 id
  final int? roomid;

  /// 直播反馈项（不感兴趣），为空时不显示该项
  final List<Feedback>? feedback;

  /// 屏蔽/反馈成功后回调，用于从列表中移除该卡片
  final VoidCallback? onRemove;

  final double? iconSize;
  final double menuItemHeight;

  const LivePopupMenu({
    super.key,
    required this.uid,
    required this.uname,
    this.roomid,
    this.feedback,
    this.onRemove,
    this.iconSize,
    this.menuItemHeight = 45,
  });

  /// 直播间链接
  String? get _roomUrl =>
      roomid == null ? null : 'https://live.bilibili.com/$roomid';

  /// 直播「不感兴趣」弹框（原 LiveCardVApp 中的实现，迁移至此便于两处复用）
  void _showFeedbackDialog(BuildContext context) {
    final theme = Theme.of(context);
    Widget actionButton(Reason r) => SearchText(
      text: r.name!,
      onTap: (_) async {
        Get.back();
        SmartDialog.showLoading(msg: '正在提交');
        final res = await LiveHttp.liveFeedback(roomid!, r.id!, r.idType!);
        SmartDialog.dismiss();
        if (res.isSuccess) {
          SmartDialog.showToast('提交成功');
          onRemove?.call();
        } else {
          res.toast();
        }
      },
    );

    final feedback = this.feedback!;
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          contentPadding: const .fromLTRB(24, 16, 24, 19),
          children: [
            for (var i in feedback) ...[
              const SizedBox(height: 5),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: i.title,
                      style: theme.textTheme.titleMedium,
                    ),
                    TextSpan(
                      text: '\n${i.subtitle}',
                      style: TextStyle(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: i.reasons!.map(actionButton).toList(),
              ),
            ],
            const Divider(),
            Center(
              child: FilledButton.tonal(
                onPressed: Get.back,
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('取消'),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 拉黑弹框：与视频卡片一致，支持本地屏蔽 / 在线拉黑
  void _showBlockDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('提示'),
          content: Text(
            '确定拉黑:${uname ?? uid}($uid)?'
            '\n\n注：被拉黑的Up可以在 设置-屏蔽过滤设置-黑名单管理 中解除',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Get.back();
                LocalBlacklist.addMid(uid);
                SmartDialog.showToast('本地屏蔽成功');
                onRemove?.call();
              },
              child: const Text('本地屏蔽'),
            ),
            TextButton(
              onPressed: Get.back,
              child: Text(
                '取消',
                style: TextStyle(color: ColorScheme.of(context).outline),
              ),
            ),
            TextButton(
              onPressed: () async {
                if (!Accounts.main.isLogin) {
                  SmartDialog.showToast('账号未登录');
                  return;
                }
                Get.back();
                final res = await VideoHttp.relationMod(
                  mid: uid!,
                  act: 5,
                  reSrc: 11,
                );
                if (res.isSuccess) {
                  SmartDialog.showToast('拉黑成功');
                  onRemove?.call();
                } else {
                  res.toast();
                }
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      padding: EdgeInsets.zero,
      icon: Icon(
        Icons.more_vert_outlined,
        color: Theme.of(context).colorScheme.outline,
        size: iconSize,
      ),
      position: PopupMenuPosition.under,
      itemBuilder: (context) =>
          [
                if (_roomUrl case final url?)
                  _LiveCustomAction(
                    '复制直播间链接',
                    const Icon(CustomIcons.identifier_circle, size: 16),
                    () => Utils.copyText(url),
                  ),
                if (uid != null)
                  _LiveCustomAction(
                    '访问：${uname ?? uid}',
                    const Icon(MdiIcons.accountCircleOutline, size: 16),
                    () => Get.toNamed('/member?mid=$uid'),
                  ),
                if (roomid != null && feedback != null && feedback!.isNotEmpty)
                  _LiveCustomAction(
                    '不感兴趣',
                    const Icon(MdiIcons.thumbDownOutline, size: 16),
                    () => _showFeedbackDialog(context),
                  ),
                if (uid != null)
                  _LiveCustomAction(
                    '拉黑：${uname ?? uid}',
                    const Icon(MdiIcons.cancel, size: 16),
                    () => _showBlockDialog(context),
                  ),
                _LiveCustomAction(
                  "${MineController.anonymity.value ? '退出' : '进入'}无痕模式",
                  MineController.anonymity.value
                      ? const Icon(MdiIcons.incognitoOff, size: 16)
                      : const Icon(MdiIcons.incognito, size: 16),
                  MineController.onChangeAnonymity,
                ),
              ]
              .map(
                (e) => PopupMenuItem(
                  height: menuItemHeight,
                  onTap: e.onTap,
                  child: Row(
                    children: [
                      e.icon,
                      const SizedBox(width: 6),
                      Text(e.title, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              )
              .toList(),
    );
  }
}
