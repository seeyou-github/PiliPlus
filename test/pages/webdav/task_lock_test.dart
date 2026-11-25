import 'dart:async';

import 'package:PiliPlus/pages/webdav/task_lock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('任务按 FIFO 串行执行，不会重叠', () async {
    final log = <String>[];

    Future<void> job(String name, int milliseconds) async {
      log.add('$name:start');
      await Future<void>.delayed(Duration(milliseconds: milliseconds));
      log.add('$name:end');
    }

    await Future.wait([
      WebDavTaskLock.run(() => job('sync', 30)),
      WebDavTaskLock.run(() => job('backup', 5)),
      WebDavTaskLock.run(() => job('manualSync', 1)),
    ]);

    expect(log, [
      'sync:start',
      'sync:end',
      'backup:start',
      'backup:end',
      'manualSync:start',
      'manualSync:end',
    ]);
  });

  test('任务抛异常后释放锁，后续任务可以继续', () async {
    await expectLater(
      WebDavTaskLock.run<void>(() async => throw StateError('boom')),
      throwsStateError,
    );

    final result = await WebDavTaskLock.run(() async => 42);
    expect(result, 42);
  });
}
