import 'dart:async';

import 'package:PiliPlus/pages/webdav/feedback.dart';
import 'package:PiliPlus/pages/webdav/sync_status.dart';
import 'package:PiliPlus/pages/webdav/task_lock.dart';
import 'package:PiliPlus/pages/webdav/webdav.dart';
import 'package:PiliPlus/utils/config_archive.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

/// WebDAV 自动备份
///
/// 设置、本地关注 / 本地收藏、本地黑名单任意变化后，延迟合并成一次上传，
/// 远端使用固定文件名覆盖；未开启自动备份或未配置 WebDAV 时静默跳过。
///
/// 任务在静态服务层执行，与页面生命周期无关，切换页面不会中断；
/// 与同步任务共用 [WebDavTaskLock] 串行执行，同一时间只会有一个任务访问远端。
abstract final class WebDavAutoBackup {
  /// 连续修改时合并为一次上传
  static const _debounce = Duration(seconds: 30);

  static Timer? _timer;
  static bool _running = false;
  static bool _paused = false;
  static bool _pending = false;
  static final List<StreamSubscription<dynamic>> _subs = [];

  static void init() {
    if (_subs.isNotEmpty) return;
    for (final box in [
      GStorage.setting,
      GStorage.video,
      GStorage.localFollow,
      GStorage.localFav,
    ]) {
      _subs.add(box.watch().listen((_) => schedule()));
    }
    // 黑名单存在 localCache，其它键（WBI、弹幕过滤等）不属于备份内容，只响应黑名单键
    _subs.add(
      GStorage.localCache.watch().listen((event) {
        final key = event.key;
        if (key == LocalCacheKey.blackMids || key == LocalCacheKey.blackNames) {
          schedule();
        }
      }),
    );
  }

  static bool get _enabled => Pref.webdavAutoBackup && WebDav().isConfigured;

  /// 恢复备份期间暂停，避免把刚恢复的数据再自动上传一遍
  static void pause() {
    _paused = true;
    _timer?.cancel();
    _timer = null;
  }

  static void resume() => _paused = false;

  static void schedule() {
    if (_paused || !_enabled) return;
    _timer?.cancel();
    _timer = Timer(_debounce, _run);
  }

  static Future<void> _run() async {
    _timer = null;
    if (_paused || !_enabled) return;
    if (_running) {
      // 已有备份在执行或排队，合并这次请求，结束后再补一次
      _pending = true;
      return;
    }
    _running = true;
    final task = WebDavTask(WebDavTaskKind.backup, automatic: true);
    WebDavTaskCenter.start(task);
    try {
      final uploaded = await WebDavTaskLock.run(() async {
        WebDavTaskCenter.begin(task);
        // 排队期间可能进入恢复备份流程，拿到锁后再确认一次
        if (_paused || !_enabled) return false;
        final bytes = ConfigArchive.exportAllBytes();
        await WebDav().uploadBackup(bytes, WebDav.autoBackupFileName);
        return true;
      });
      if (uploaded) {
        SmartDialog.showToast('自动备份成功');
      }
    } catch (e) {
      debugPrint('[WebDavAutoBackup] 自动备份失败: $e');
      showWebDavFailure('自动备份失败', describeWebDavError(e));
    } finally {
      _running = false;
      WebDavTaskCenter.finish(task);
      if (_pending) {
        _pending = false;
        if (!_paused && _enabled) {
          _timer = Timer(_debounce, _run);
        }
      }
    }
  }
}
