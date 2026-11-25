import 'package:flutter/foundation.dart';

/// WebDAV 后台任务类型
enum WebDavTaskKind { backup, sync }

/// 一次正在执行的 WebDAV 任务
class WebDavTask {
  const WebDavTask(this.kind, {this.automatic = false});

  final WebDavTaskKind kind;

  /// 是否由自动同步 / 自动备份触发
  final bool automatic;

  String get label => switch (kind) {
    WebDavTaskKind.backup => automatic ? '正在自动备份…' : '正在备份…',
    WebDavTaskKind.sync => automatic ? '正在自动同步…' : '正在同步…',
  };
}

/// 全局 WebDAV 任务状态
///
/// 「立即同步」按钮动画与页面底部进度提示共用同一份运行状态。
abstract final class WebDavTaskCenter {
  /// 当前展示的任务：并发时取最近启动的一个，全部结束为 null
  static final ValueNotifier<WebDavTask?> current = ValueNotifier(null);

  static final List<WebDavTask> _active = [];

  static bool isRunning(WebDavTaskKind kind) =>
      _active.any((task) => task.kind == kind);

  static void start(WebDavTask task) {
    _active.add(task);
    current.value = task;
  }

  static void finish(WebDavTask task) {
    _active.remove(task);
    current.value = _active.isEmpty ? null : _active.last;
  }
}
