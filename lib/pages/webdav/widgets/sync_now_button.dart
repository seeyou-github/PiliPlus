import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/pages/webdav/sync_action.dart';
import 'package:PiliPlus/pages/webdav/sync_status.dart';
import 'package:material_ui/material_ui.dart';

/// 「立即同步」图标按钮（「我的」页顶栏）
class WebDavSyncNowIconButton extends StatelessWidget {
  const WebDavSyncNowIconButton({
    super.key,
    this.iconSize = 22,
    this.padding = const EdgeInsets.all(8),
    this.style = const ButtonStyle(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  });

  final double iconSize;
  final EdgeInsetsGeometry padding;
  final ButtonStyle style;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<WebDavTask>>(
      valueListenable: WebDavTaskCenter.active,
      builder: (context, _, _) {
        final syncing = WebDavTaskCenter.isRunning(WebDavTaskKind.sync);
        return IconButton(
          iconSize: iconSize,
          padding: padding,
          style: style,
          tooltip: syncing ? '正在同步' : '立即同步',
          onPressed: syncing ? null : WebDavSyncAction.runNow,
          icon: syncing
              ? _SpinningSyncIcon(size: iconSize - 4)
              : const Icon(Icons.sync),
        );
      },
    );
  }
}

/// 「立即同步」按钮（备份还原设置页）
class WebDavSyncNowButton extends StatelessWidget {
  const WebDavSyncNowButton({super.key, this.beforeSync});

  /// 同步前执行，用于保存设置页输入框中的 WebDAV 配置
  final Future<void> Function()? beforeSync;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<WebDavTask>>(
      valueListenable: WebDavTaskCenter.active,
      builder: (context, _, _) {
        final syncing = WebDavTaskCenter.isRunning(WebDavTaskKind.sync);
        return FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            shape: const RoundedRectangleBorder(borderRadius: Style.mdRadius),
          ),
          onPressed: syncing
              ? null
              : () => WebDavSyncAction.runNow(saveConfig: beforeSync),
          icon: syncing
              ? const _SpinningSyncIcon(size: 16)
              : const Icon(Icons.sync, size: 18),
          label: Text(syncing ? '正在同步' : '立即同步'),
        );
      },
    );
  }
}

/// 同步进行中持续旋转的图标
class _SpinningSyncIcon extends StatefulWidget {
  const _SpinningSyncIcon({required this.size});

  final double size;

  @override
  State<_SpinningSyncIcon> createState() => _SpinningSyncIconState();
}

class _SpinningSyncIconState extends State<_SpinningSyncIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(Icons.sync, size: widget.size),
    );
  }
}
