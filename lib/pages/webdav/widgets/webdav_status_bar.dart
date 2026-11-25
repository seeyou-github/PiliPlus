import 'package:PiliPlus/pages/webdav/sync_status.dart';
import 'package:material_ui/material_ui.dart';

/// WebDAV 后台任务进行中的底部提示条
///
/// 由 [WebDavTaskCenter] 驱动：同步 / 备份任务开始真正执行时从底部展开并显示
/// 进度动画，任务结束后收起。提示条挂在 App 根部，切换页面不会消失。
class WebDavStatusBar extends StatelessWidget {
  const WebDavStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<WebDavTask>>(
      valueListenable: WebDavTaskCenter.active,
      builder: (context, _, _) {
        final task = WebDavTaskCenter.executing;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            axisAlignment: 1,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: task == null
              ? const SizedBox.shrink(key: ValueKey('webdavStatusEmpty'))
              : _TaskBar(task: task, key: ValueKey(task)),
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
