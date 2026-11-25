import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/view_insets_safe_area.dart';
import 'package:PiliPlus/pages/webdav/auto_sync.dart';
import 'package:PiliPlus/pages/webdav/controller.dart';
import 'package:PiliPlus/pages/webdav/webdav.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class WebDavSettingPage extends StatefulWidget {
  const WebDavSettingPage({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  State<WebDavSettingPage> createState() => _WebDavSettingPageState();
}

class _WebDavSettingPageState extends State<WebDavSettingPage> {
  final _uriCtr = TextEditingController(text: Pref.webdavUri);
  final _usernameCtr = TextEditingController(text: Pref.webdavUsername);
  final _passwordCtr = TextEditingController(text: Pref.webdavPassword);
  // 常驻实例：离开页面后备份仍可继续，返回页面时仍能看到进度
  final controller = Get.isRegistered<WebDavController>()
      ? Get.find<WebDavController>()
      : Get.put(WebDavController(), permanent: true);
  bool _obscureText = true;
  bool _autoBackup = Pref.webdavAutoBackup;
  bool _autoSync = Pref.webdavAutoSync;

  @override
  void dispose() {
    _uriCtr.dispose();
    _usernameCtr.dispose();
    _passwordCtr.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() => controller.saveConfig(
    uri: _uriCtr.text,
    username: _usernameCtr.text,
    password: _passwordCtr.text,
  );

  Future<void> _save() async {
    await _saveConfig();
    if (!WebDav().isConfigured) {
      SmartDialog.showToast(_uriCtr.text.trim().isEmpty ? '已保存' : '地址格式不正确');
      return;
    }
    SmartDialog.showLoading();
    final error = await controller.testConnection();
    SmartDialog.dismiss();
    if (error == null) {
      SmartDialog.showToast('配置成功');
      WebDavAutoSync.schedule(force: true);
    } else {
      SmartDialog.showToast('配置失败：$error');
    }
  }

  /// 点击备份先保存配置：无论备份是否失败都保留用户填写的地址与账号
  Future<void> _backup() async {
    await _saveConfig();
    await controller.backup();
  }

  Future<void> _setAutoBackup(bool value) async {
    setState(() => _autoBackup = value);
    await GStorage.setting.put(SettingBoxKey.webdavAutoBackup, value);
    if (value) {
      if (_uriCtr.text.trim().isEmpty) {
        SmartDialog.showToast('请先填写并保存 WebDAV 地址');
      } else {
        WebDavAutoSync.schedule(force: true);
      }
    }
  }

  Future<void> _setAutoSync(bool value) async {
    setState(() => _autoSync = value);
    await GStorage.setting.put(SettingBoxKey.webdavAutoSync, value);
    if (!value) return;
    if (!_autoBackup) {
      SmartDialog.showToast('请先开启自动备份');
    } else if (_uriCtr.text.trim().isEmpty) {
      SmartDialog.showToast('请先填写并保存 WebDAV 地址');
    } else {
      WebDavAutoSync.schedule(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showAppBar = widget.showAppBar;
    final padding = MediaQuery.viewPaddingOf(context);
    return SimpleScaffold(
      appBar: showAppBar ? AppBar(title: const Text('WebDAV 设置')) : null,
      body: ViewInsetsSafeArea(
        child: ListView(
          padding: padding.copyWith(
            top: 20,
            left: 20 + (showAppBar ? padding.left : 0),
            right: 20 + (showAppBar ? padding.right : 0),
            bottom: padding.bottom + 100,
          ),
          children: [
            TextField(
              controller: _uriCtr,
              decoration: const InputDecoration(
                labelText: '地址',
                hintText: 'https://dav.example.com/dav/App_Sync',
                helperText: '备份将保存在该地址下的 PiliPlus 目录',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _usernameCtr,
              decoration: const InputDecoration(
                labelText: '用户',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordCtr,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: '密码',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                  icon: _obscureText
                      ? const Icon(Icons.visibility)
                      : const Icon(Icons.visibility_off),
                ),
              ),
              obscureText: _obscureText,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('自动备份'),
              subtitle: const Text('设置变更或本地关注 / 收藏 / 黑名单变化后自动备份'),
              value: _autoBackup,
              onChanged: _setAutoBackup,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('自动同步'),
              subtitle: const Text('自动备份开启后，在设备间同步本地关注 / 收藏 / 黑名单'),
              value: _autoSync,
              onChanged: _setAutoSync,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _backupButton()),
                const SizedBox(width: 20),
                Expanded(child: _restoreButton()),
              ],
            ),
          ],
        ),
      ),
      fab: Padding(
        padding: .only(
          right: kFloatingActionButtonMargin + (showAppBar ? padding.right : 0),
          bottom: kFloatingActionButtonMargin + padding.bottom,
        ),
        child: ViewInsetsSafeArea(
          child: FloatingActionButton(
            child: const Icon(Icons.save),
            onPressed: _save,
          ),
        ),
      ),
    );
  }

  Widget _backupButton() {
    return Obx(() {
      final busy = controller.busy;
      return FilledButton.tonal(
        style: FilledButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: Style.mdRadius),
        ),
        onPressed: busy ? null : _backup,
        child: controller.backingUp.value
            ? const Row(
                mainAxisAlignment: .center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('正在备份'),
                ],
              )
            : const Text('备份设置'),
      );
    });
  }

  Widget _restoreButton() {
    return Obx(() {
      final busy = controller.busy;
      return FilledButton.tonal(
        style: FilledButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: Style.mdRadius),
        ),
        onPressed: busy ? null : controller.restore,
        child: controller.restoring.value
            ? const Row(
                mainAxisAlignment: .center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('正在恢复'),
                ],
              )
            : const Text('恢复设置'),
      );
    });
  }
}
