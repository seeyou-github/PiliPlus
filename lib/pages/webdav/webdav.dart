import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:dio/dio.dart' as dio;
import 'package:webdav_client/webdav_client.dart' as webdav;

/// 远端备份文件
class WebDavBackupFile {
  const WebDavBackupFile({
    required this.name,
    required this.size,
    required this.modified,
  });

  final String name;
  final int size;
  final DateTime? modified;
}

/// 带可读原因的 WebDAV 异常
class WebDavException implements Exception {
  const WebDavException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// 把网络 / WebDAV 异常转换成用户可读的文案
String describeWebDavError(Object error) {
  if (_mentionsNoHost(error)) {
    return 'WebDAV 地址不正确（缺少主机名），请填写完整地址';
  }
  if (error is WebDavException) {
    final code = error.statusCode;
    if (code == null || error.message.contains('HTTP $code')) {
      return error.message;
    }
    return '${error.message}（HTTP $code）';
  }
  if (error is dio.DioException) {
    switch (error.type) {
      case dio.DioExceptionType.connectionTimeout:
        return '网络超时：连接服务器超时，请检查网络或地址';
      case dio.DioExceptionType.sendTimeout:
        return '网络超时：上传超时，请检查网络';
      case dio.DioExceptionType.receiveTimeout:
      case dio.DioExceptionType.transformTimeout:
        return '网络超时：服务器响应过慢，请稍后重试';
      case dio.DioExceptionType.badCertificate:
        return '证书错误：HTTPS 证书校验失败';
      case dio.DioExceptionType.connectionError:
        return '网络错误：无法访问服务器${_causeOf(error)}';
      case dio.DioExceptionType.cancel:
        return '请求已取消';
      case dio.DioExceptionType.badResponse:
        final code = error.response?.statusCode;
        final message = error.response?.statusMessage;
        return '服务器返回错误：HTTP ${code ?? '未知'}'
            '${message == null || message.isEmpty ? '' : ' $message'}';
      case dio.DioExceptionType.unknown:
        return '网络异常${_causeOf(error)}';
    }
  }
  final text = '$error';
  return text.length > 200 ? '${text.substring(0, 200)}…' : text;
}

bool _mentionsNoHost(Object error) {
  if ('$error'.contains('No host specified')) return true;
  if (error is dio.DioException) {
    return '${error.message}${error.error ?? ''}'.contains('No host specified');
  }
  return false;
}

String _causeOf(dio.DioException error) {
  final inner = error.error;
  if (inner == null) return '';
  final text = '$inner';
  if (text.trim().isEmpty) return '';
  return '：${text.length > 120 ? '${text.substring(0, 120)}…' : text}';
}

/// WebDAV 备份客户端
///
/// 地址栏填写完整地址（含目录），备份统一保存在 `<地址>/PiliPlus/` 下。
class WebDav {
  WebDav._internal();
  static final WebDav _instance = WebDav._internal();
  factory WebDav() => _instance;

  /// 远端备份目录（相对配置地址）
  static const folderName = Constants.appName;

  /// 手动备份的文件名前缀
  static const backupNamePrefix = 'PiliPlus_backup_';

  /// 当前平台的备份文件名前缀，用于隔离各平台的备份
  static String get platformPrefix {
    if (Platform.isWindows) return 'Windows_';
    if (Platform.isAndroid) return 'Android_';
    if (Platform.isIOS) return 'iOS_';
    if (Platform.isMacOS) return 'macOS_';
    if (Platform.isLinux) return 'Linux_';
    return '';
  }

  /// 自动备份的固定文件名（每次覆盖）
  static String get autoBackupFileName =>
      '${platformPrefix}AutoBackup_Piliplus.zip';

  /// 跨设备同步数据文件名（全平台共用）
  static const syncFileName = 'Sync_Piliplus.json';

  /// 旧版「路径」设置项，已废弃，仅用于升级迁移
  static const _legacyDirectoryKey = 'webdavDirectory';

  webdav.Client? _client;
  ({String uri, String username, String password})? _clientConfig;
  Future<void> _uploadChain = Future<void>.value();
  bool _uploading = false;

  bool get uploading => _uploading;

  bool get isConfigured {
    final uri = Uri.tryParse(Pref.webdavUri.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  Future<void> saveConfig({
    required String uri,
    required String username,
    required String password,
  }) async {
    await GStorage.setting.putAll({
      SettingBoxKey.webdavUri: uri.trim(),
      SettingBoxKey.webdavUsername: username.trim(),
      SettingBoxKey.webdavPassword: password,
    });
    _clientConfig = null;
    _client = null;
  }

  /// 升级迁移：旧版把路径单独存一项，最终目录为 `<地址>/<路径>/PiliPlus`。
  /// 这里把路径并入地址，保持备份落在原来的位置；迁移完成后删除旧键。
  static Future<void> migrateLegacyConfig() async {
    final box = GStorage.setting;
    final legacy = box.get(_legacyDirectoryKey);
    if (legacy == null) return;
    final dir = '$legacy'.replaceAll(RegExp(r'^/+|/+$'), '').trim();
    final uri = '${box.get(SettingBoxKey.webdavUri) ?? ''}'.trim();
    if (dir.isNotEmpty && uri.isNotEmpty) {
      final parsed = Uri.tryParse(uri);
      if (parsed != null && parsed.host.isNotEmpty) {
        final base = uri.endsWith('/') ? uri.substring(0, uri.length - 1) : uri;
        // 幂等：地址已经包含该路径时不再重复拼接
        if (base != dir && !base.endsWith('/$dir')) {
          await box.put(SettingBoxKey.webdavUri, '$base/$dir');
        }
      }
    }
    await box.delete(_legacyDirectoryKey);
  }

  String get _folderPath => '/$folderName';
  String _filePath(String name) => '$_folderPath/$name';

  Future<webdav.Client> _connect({bool force = false}) async {
    if (!isConfigured) {
      throw const WebDavException('请填写包含 http(s):// 的 WebDAV 地址');
    }
    final config = (
      uri: Pref.webdavUri.trim(),
      username: Pref.webdavUsername,
      password: Pref.webdavPassword,
    );
    final cached = _client;
    if (!force && cached != null && _clientConfig == config) return cached;

    final client =
        webdav.newClient(
            config.uri,
            user: config.username,
            password: config.password,
          )
          ..setHeaders({'accept-charset': 'utf-8'})
          ..setConnectTimeout(15000)
          ..setReceiveTimeout(30000)
          ..setSendTimeout(30000);
    _client = client;
    _clientConfig = config;
    return client;
  }

  /// 测试连接并创建备份目录；返回 null 表示成功，否则是失败原因
  Future<String?> testConnection() async {
    try {
      final client = await _connect(force: true);
      await client.mkdirAll(_folderPath);
      return null;
    } catch (e) {
      return describeWebDavError(e);
    }
  }

  /// 串行执行上传：自动备份与手动备份同时触发时排队，避免相互打断
  Future<void> uploadBackup(Uint8List bytes, String fileName) {
    final completer = Completer<void>();
    _uploadChain = _uploadChain.then((_) async {
      _uploading = true;
      try {
        final client = await _connect();
        await client.mkdirAll(_folderPath);
        await client.write(_filePath(fileName), bytes);
        completer.complete();
      } catch (e, st) {
        completer.completeError(e, st);
      } finally {
        _uploading = false;
      }
    });
    return completer.future;
  }

  /// 远端备份列表（按修改时间倒序）
  Future<List<WebDavBackupFile>> listBackups() async {
    final client = await _connect();
    // 先确保目录存在，避免首次读取时 PROPFIND 返回 404
    await client.mkdirAll(_folderPath);
    final List<webdav.File> items;
    try {
      items = await client.readDir(_folderPath);
    } on dio.DioException catch (e) {
      // 目录还不存在时视为没有备份
      if (e.response?.statusCode == 404) return const [];
      rethrow;
    }
    final list = <WebDavBackupFile>[];
    for (final item in items) {
      if (item.isDir == true) continue;
      final name = item.name ?? '';
      if (name.isEmpty || name == '.' || name == '..') continue;
      if (!name.toLowerCase().endsWith('.zip')) continue;
      // 只显示当前平台的备份
      if (!name.startsWith(platformPrefix)) continue;
      list.add(
        WebDavBackupFile(
          name: name,
          size: item.size ?? 0,
          modified: item.mTime,
        ),
      );
    }
    list.sort(
      (a, b) =>
          (b.modified ?? DateTime(0)).compareTo(a.modified ?? DateTime(0)),
    );
    return list;
  }

  /// 直接 GET 下载，绕过 `client.read()` 的 OPTIONS 预检（部分服务器会 301），
  /// 并放宽空闲超时，避免大文件被误判超时
  Future<Uint8List> downloadBackup(String name) async {
    final client = await _connect();
    final response = await client.c.req<dynamic>(
      client,
      'GET',
      _filePath(name),
      optionsHandler: (options) {
        options.responseType = dio.ResponseType.bytes;
        options.followRedirects = true;
        options.validateStatus = (status) => status != null;
        options.receiveTimeout = const Duration(minutes: 2);
      },
    );
    final status = response.statusCode ?? 0;
    if (status != 200) {
      if (status == 404) {
        throw const WebDavException('远端文件不存在（HTTP 404）', statusCode: 404);
      }
      throw WebDavException('下载失败：HTTP $status', statusCode: status);
    }
    final data = response.data;
    if (data is Uint8List) return data;
    if (data is List<int>) return Uint8List.fromList(data);
    throw const WebDavException('下载失败：服务器没有返回数据');
  }

  /// 读取同步文件；不存在时返回 null
  Future<Uint8List?> downloadIfExists(String name) async {
    try {
      return await downloadBackup(name);
    } on WebDavException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> deleteBackup(String name) async {
    final client = await _connect();
    await client.remove(_filePath(name));
  }

  /// 手动备份文件名：`PiliPlus_backup_年.月.日-时:分:秒.zip`
  static String buildBackupFileName([DateTime? now]) {
    final t = now ?? DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '$platformPrefix$backupNamePrefix'
        '${t.year}.${two(t.month)}.${two(t.day)}-'
        '${two(t.hour)}:${two(t.minute)}:${two(t.second)}.zip';
  }
}
