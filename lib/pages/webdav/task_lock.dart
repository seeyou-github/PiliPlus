import 'dart:async';

/// WebDAV 后台任务串行锁
///
/// 同步（自动 / 手动）与备份共用同一把锁：同一时间只允许一个任务访问远端，
/// 后到的任务按先后顺序排队，前一个任务结束后立即开始。
///
/// 不支持重入：在已持有锁的任务里再调用 [run] 会抛 [StateError]，
/// 而不是互相等待造成死锁。
abstract final class WebDavTaskLock {
  static Future<void> _tail = Future<void>.value();

  /// 标记「当前 Zone 已持有锁」，用于检测重入
  static final Object _zoneKey = Object();

  /// 排队执行 [action]，返回其执行结果
  static Future<T> run<T>(Future<T> Function() action) async {
    if (Zone.current[_zoneKey] == true) {
      throw StateError('WebDavTaskLock 不支持重入：请在锁外调用 run()');
    }
    final gate = Completer<void>();
    final previous = _tail;
    _tail = gate.future;
    try {
      return await runZoned(
        () async {
          await previous;
          return action();
        },
        zoneValues: {_zoneKey: true},
      );
    } finally {
      if (!gate.isCompleted) gate.complete();
    }
  }
}
