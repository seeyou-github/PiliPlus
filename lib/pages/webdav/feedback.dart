import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// 显示 WebDAV 任务失败提示
///
/// 优先使用全局上下文弹框（可附带重试），没有可用上下文时降级为 toast。
void showWebDavFailure(
  String title,
  String message, {
  Future<void> Function()? retry,
}) {
  final context = Get.key.currentState?.overlay?.context;
  if (context == null) {
    SmartDialog.showToast('$title：$message');
    return;
  }
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: Text(message)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('知道了'),
        ),
        if (retry != null)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              retry();
            },
            child: const Text('重试'),
          ),
      ],
    ),
  );
}
