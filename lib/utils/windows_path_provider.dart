import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

abstract final class WindowsPathProvider {
  static void usePortableAppData() {
    if (Platform.isWindows) {
      PathProviderPlatform.instance = _PortableWindowsPathProvider();
    }
  }
}

final class _PortableWindowsPathProvider extends PathProviderPlatform {
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
