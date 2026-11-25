import 'package:PiliPlus/pages/webdav/auto_sync.dart';
import 'package:PiliPlus/pages/webdav/feedback.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

/// 「立即同步」动作：手动触发一次同步并给出结果反馈
abstract final class WebDavSyncAction {
  /// [saveConfig] 用于设置页先保存输入框中的 WebDAV 配置
  static Future<void> runNow({Future<void> Function()? saveConfig}) async {
    if (saveConfig != null) await saveConfig();
    final result = await WebDavAutoSync.syncNow();
    switch (result.outcome) {
      case WebDavSyncOutcome.success:
        SmartDialog.showToast('同步成功');
      case WebDavSyncOutcome.failure:
        showWebDavFailure(
          '同步失败',
          result.message ?? '未知错误',
          retry: () => runNow(saveConfig: saveConfig),
        );
      case WebDavSyncOutcome.skipped:
        // 同步已在执行（或正在恢复备份）：给出反馈，避免点了「立即同步」毫无反应
        SmartDialog.showToast(result.message ?? '同步进行中，请稍候');
    }
  }
}
