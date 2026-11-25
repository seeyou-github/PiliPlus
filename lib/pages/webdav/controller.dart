import 'package:PiliPlus/pages/webdav/webdav.dart';
import 'package:PiliPlus/pages/webdav/widgets/remote_backup_sheet.dart';
import 'package:PiliPlus/utils/config_archive.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// WebDAV 备份 / 还原
///
/// 常驻 Get 实例：手动备份在离开页面后继续执行，结果通过全局提示 / 弹框反馈。
class WebDavController extends GetxController {
  final backingUp = false.obs;
  final restoring = false.obs;

  bool get busy => backingUp.value || restoring.value;

  /// 全局对话框上下文：页面已关闭时仍能弹框
  BuildContext? get _context => Get.key.currentState?.overlay?.context;

  Future<void> saveConfig({
    required String uri,
    required String username,
    required String password,
  }) => WebDav().saveConfig(
    uri: uri,
    username: username,
    password: password,
  );

  Future<String?> testConnection() => WebDav().testConnection();

  Future<void> backup() async {
    if (busy) return;
    backingUp.value = true;
    try {
      final bytes = ConfigArchive.exportLocalBytes();
      await WebDav().uploadBackup(bytes, WebDav.buildBackupFileName());
      SmartDialog.showToast('备份成功');
    } catch (e) {
      _showFailure('备份失败', describeWebDavError(e), retry: backup);
    } finally {
      backingUp.value = false;
    }
  }

  Future<void> restore() async {
    if (busy) return;
    final context = _context;
    if (context == null) return;
    restoring.value = true;
    final List<WebDavBackupFile> files;
    try {
      files = await WebDav().listBackups();
    } catch (e) {
      restoring.value = false;
      _showFailure('读取备份列表失败', describeWebDavError(e), retry: restore);
      return;
    }
    restoring.value = false;
    if (files.isEmpty) {
      SmartDialog.showToast('云端暂无备份文件');
      return;
    }
    final picked = await showModalBottomSheet<WebDavBackupFile>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => RemoteBackupSheet(files: files),
    );
    if (picked == null) return;
    if (!await _confirmRestore(picked.name)) return;
    await _restoreFile(picked.name);
  }

  Future<void> _restoreFile(String name) async {
    restoring.value = true;
    try {
      final bytes = await WebDav().downloadBackup(name);
      final message = await ConfigArchive.import(
        bytes,
        onWarning: _confirmWarning,
      );
      if (message == null) return;
      SmartDialog.showToast(message.isEmpty ? '恢复成功' : '恢复成功，但$message');
    } catch (e) {
      _showFailure('恢复失败', describeWebDavError(e));
    } finally {
      restoring.value = false;
    }
  }

  Future<bool> _confirmRestore(String name) async {
    final context = _context;
    if (context == null) return false;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('恢复设置'),
            content: Text(
              '将用「$name」中的本地关注、本地收藏与黑名单合并到当前数据，'
              '同名项以备份为准。此操作不可撤销。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('恢复'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _confirmWarning(String warning) async {
    final context = _context;
    if (context == null) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('注意'),
            content: Text(warning),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('继续'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showFailure(
    String title,
    String message, {
    Future<void> Function()? retry,
  }) {
    final context = _context;
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
            child: const Text('取消'),
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
}
