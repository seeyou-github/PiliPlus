import 'dart:async';

import 'package:PiliPlus/pages/webdav/webdav.dart';
import 'package:PiliPlus/utils/config_archive.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// WebDAV 自动备份
///
/// 设置、本地关注 / 本地收藏、本地黑名单任意变化后，延迟合并成一次上传，
/// 远端使用固定文件名覆盖；未开启自动备份或未配置 WebDAV 时静默跳过。
abstract final class WebDavAutoBackup {
  /// 连续修改时合并为一次上传
  static const _debounce = Duration(seconds: 30);

  static Timer? _timer;
  static bool _running = false;
  static final List<StreamSubscription<dynamic>> _subs = [];

  static void init() {
    if (_subs.isNotEmpty) return;
    for (final box in [
      GStorage.setting,
      GStorage.video,
      GStorage.localCache,
      GStorage.localFollow,
      GStorage.localFav,
    ]) {
      _subs.add(box.watch().listen((_) => schedule()));
    }
  }

  static bool get _enabled => Pref.webdavAutoBackup && WebDav().isConfigured;

  static void schedule() {
    if (!_enabled) return;
    _timer?.cancel();
    _timer = Timer(_debounce, _run);
  }

  static Future<void> _run() async {
    _timer = null;
    if (!_enabled || _running) return;
    _running = true;
    try {
      final bytes = ConfigArchive.exportLocalBytes();
      await WebDav().uploadBackup(bytes, WebDav.autoBackupFileName);
    } catch (e) {
      debugPrint('[WebDavAutoBackup] 自动备份失败: $e');
    } finally {
      _running = false;
    }
  }
}
