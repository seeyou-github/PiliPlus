import 'dart:async';

/// WebDAV 后台任务串行锁
///
/// 同步（自动 / 手动）与备份共用同一把锁：同一时间只允许一个任务访问远端，
/// 后到的任务按先后顺序排队，前一个任务结束后立即开始。
abstract final class WebDavTaskLock {
  static Future<void> _tail = Future<void>.value();

  /// 排队执行 [action]，返回其执行结果
  static Future<T> run<T>(Future<T> Function() action) async {
    final gate = Completer<void>();
    final previous = _tail;
    _tail = gate.future;
    try {
      await previous;
      return await action();
    } finally {
      if (!gate.isCompleted) gate.complete();
    }
  }
}
