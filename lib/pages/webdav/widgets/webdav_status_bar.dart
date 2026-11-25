import 'package:PiliPlus/pages/webdav/sync_status.dart';
import 'package:material_ui/material_ui.dart';

/// 自动同步 / 自动备份进行中的底部提示条
///
/// 由 [WebDavTaskCenter] 驱动：自动任务开始时从底部展开并显示进度动画，
/// 任务结束后收起。
class WebDavStatusBar extends StatelessWidget {
  const WebDavStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<WebDavTask?>(
      valueListenable: WebDavTaskCenter.current,
      builder: (context, task, _) {
        final show = task != null && task.automatic;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            axisAlignment: 1,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: show
              ? _TaskBar(task: task, key: ValueKey(task))
              : const SizedBox.shrink(key: ValueKey('webdavStatusEmpty')),
        );
      },
    );
  }
}

class _TaskBar extends StatelessWidget {
  const _TaskBar({super.key, required this.task});

  final WebDavTask task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: colorScheme.secondaryContainer,
      elevation: 4,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  task.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
