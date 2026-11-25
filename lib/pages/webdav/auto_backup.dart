import 'dart:async';

import 'package:PiliPlus/pages/webdav/feedback.dart';
import 'package:PiliPlus/pages/webdav/sync_status.dart';
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
abstract final class WebDavAutoBackup {
  /// 连续修改时合并为一次上传
  static const _debounce = Duration(seconds: 30);

  static Timer? _timer;
  static bool _running = false;
  static bool _paused = false;
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
    if (_paused || !_enabled || _running) return;
    _running = true;
    final task = WebDavTask(WebDavTaskKind.backup, automatic: true);
    WebDavTaskCenter.start(task);
    try {
      final bytes = ConfigArchive.exportAllBytes();
      await WebDav().uploadBackup(bytes, WebDav.autoBackupFileName);
      SmartDialog.showToast('自动备份成功');
    } catch (e) {
      debugPrint('[WebDavAutoBackup] 自动备份失败: $e');
      showWebDavFailure('自动备份失败', describeWebDavError(e));
    } finally {
      _running = false;
      WebDavTaskCenter.finish(task);
    }
  }
}
