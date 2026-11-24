import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_windows/shared_preferences_windows.dart';

abstract final class WindowsPathProvider {
  static void usePortableAppData() {
    if (Platform.isWindows) {
      final provider = _PortableWindowsPathProvider();
      PathProviderPlatform.instance = provider;
      _usePortableSharedPreferencesPath(provider);
    }
  }

  /// shared_preferences_windows 会自建 PathProviderWindows，绕过平台全局实例。
  /// 这里把两个实例的 pathProvider 都换成便携实现，避免生成
  /// %APPDATA%\com.example\piliplus。
  static void _usePortableSharedPreferencesPath(
    _PortableWindowsPathProvider provider,
  ) {
    final store = SharedPreferencesStorePlatform.instance;
    if (store is SharedPreferencesWindows) {
      store.pathProvider = provider;
    }
    final asyncStore = SharedPreferencesAsyncPlatform.instance;
    if (asyncStore is SharedPreferencesAsyncWindows) {
      asyncStore.pathProvider = provider;
    }
  }
}

final class _PortableWindowsPathProvider extends PathProviderWindows {
  late final String _exeDir = path.dirname(Platform.resolvedExecutable);

  late final String _configDir = _ensureDir(
    path.join(_exeDir, 'AppData', 'Config'),
  );

  late final String _cacheDir = _ensureDir(
    path.join(_exeDir, 'AppData', 'cache'),
  );

  String _ensureDir(String dirPath) {
    Directory(dirPath).createSync(recursive: true);
    return dirPath;
  }

  @override
  Future<String?> getTemporaryPath() async => _cacheDir;

  @override
  Future<String?> getApplicationCachePath() async => _cacheDir;

  @override
  Future<String?> getApplicationSupportPath() async => _configDir;

  @override
  Future<String?> getApplicationDocumentsPath() async => _configDir;

  @override
  Future<String?> getLibraryPath() async => _configDir;

  @override
  Future<String?> getDownloadsPath() async => _configDir;
}
