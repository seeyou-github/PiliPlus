import 'package:PiliPlus/pages/webdav/auto_sync.dart';
import 'package:PiliPlus/pages/webdav/feedback.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

/// 「立即同步」动作：手动触发一次同步并给出结果反馈
abstract final class WebDavSyncAction {
  static Future<void> runNow() async {
    final result = await WebDavAutoSync.syncNow();
    switch (result.outcome) {
      case WebDavSyncOutcome.success:
        SmartDialog.showToast('同步成功');
      case WebDavSyncOutcome.failure:
        showWebDavFailure('同步失败', result.message ?? '未知错误', retry: runNow);
      case WebDavSyncOutcome.skipped:
        break;
    }
  }
}
