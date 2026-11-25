import 'package:flutter/foundation.dart';

/// WebDAV 后台任务类型
enum WebDavTaskKind { backup, sync }

/// 一次 WebDAV 任务（执行中或排队等待中）
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
/// 任务本身在静态服务层执行，与页面生命周期无关，切换页面不会中断；
/// 这里只维护界面需要的运行状态，供按钮动画与底部进度提示使用。
abstract final class WebDavTaskCenter {
  /// 所有任务（含排队等待锁的任务）；每次状态变化都会通知
  static final ValueNotifier<List<WebDavTask>> active = ValueNotifier(
    const <WebDavTask>[],
  );

  static final List<WebDavTask> _tasks = [];

  static WebDavTask? _executing;

  /// 当前真正在执行的任务（排队等待的不算）
  static WebDavTask? get executing => _executing;

  /// 是否有该类型的任务在排队或执行
  static bool isRunning(WebDavTaskKind kind) =>
      _tasks.any((task) => task.kind == kind);

  static void start(WebDavTask task) {
    _tasks.add(task);
    _notify();
  }

  /// 任务获取到串行锁、开始真正执行
  static void begin(WebDavTask task) {
    _executing = task;
    _notify();
  }

  static void finish(WebDavTask task) {
    _tasks.remove(task);
    if (identical(_executing, task)) _executing = null;
    _notify();
  }

  static void _notify() => active.value = List<WebDavTask>.unmodifiable(_tasks);
}
