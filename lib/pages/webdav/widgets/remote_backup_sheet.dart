import 'package:PiliPlus/pages/webdav/webdav.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';

/// 远端备份列表：点击条目恢复，右侧按钮删除远端文件
class RemoteBackupSheet extends StatefulWidget {
  const RemoteBackupSheet({super.key, required this.files});

  final List<WebDavBackupFile> files;

  @override
  State<RemoteBackupSheet> createState() => _RemoteBackupSheetState();
}

class _RemoteBackupSheetState extends State<RemoteBackupSheet> {
  late final List<WebDavBackupFile> _files = List.of(widget.files);
  final Set<String> _deleting = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: Column(
        mainAxisSize: .min,
        children: [
          Padding(
            padding: const .fromLTRB(20, 12, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '选择备份文件',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          if (_files.isEmpty)
            Padding(
              padding: const .all(32),
              child: Text(
                '云端暂无备份文件',
                style: TextStyle(color: theme.colorScheme.outline),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _files.length,
                itemBuilder: (context, index) {
                  final file = _files[index];
                  final deleting = _deleting.contains(file.name);
                  return ListTile(
                    title: Text(
                      file.name,
                      maxLines: 1,
                      overflow: .ellipsis,
                    ),
                    subtitle: Text(
                      _subtitleOf(file),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    trailing: deleting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            tooltip: '删除远端备份',
                            onPressed: () => _delete(file),
                            icon: const Icon(Icons.delete_outline),
                          ),
                    onTap: deleting ? null : () => Navigator.pop(context, file),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _subtitleOf(WebDavBackupFile file) {
    final parts = <String>[];
    final time = file.modified;
    if (time != null) {
      String two(int v) => v.toString().padLeft(2, '0');
      parts.add(
        '${time.year}-${two(time.month)}-${two(time.day)} '
        '${two(time.hour)}:${two(time.minute)}',
      );
    }
    if (file.size > 0) parts.add(_formatSize(file.size));
    return parts.join(' · ');
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  Future<void> _delete(WebDavBackupFile file) async {
    if (_deleting.contains(file.name)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除远端备份'),
        content: Text('确定删除「${file.name}」吗？删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting.add(file.name));
    try {
      await WebDav().deleteBackup(file.name);
      if (!mounted) return;
      setState(() => _files.remove(file));
      SmartDialog.showToast('已删除');
    } catch (e) {
      if (!mounted) return;
      SmartDialog.showToast('删除失败：${describeWebDavError(e)}');
    } finally {
      if (mounted) setState(() => _deleting.remove(file.name));
    }
  }
}
