import 'dart:convert';
import 'dart:io';

import 'package:PiliPlus/services/logger.dart';
import 'package:catcher_2/catcher_2.dart';

class JsonFileHandler extends ReportHandler {
  final bool enableDeviceParameters;
  final bool enableApplicationParameters;
  final bool enableStackTrace;
  final bool enableCustomParameters;
  final bool printLogs;
  final bool handleWhenRejected;

  static Future<RandomAccessFile>? _future;

  static Future<RandomAccessFile> _ensureFuture() =>
      _future ??= LoggerUtils.getLogsPath()
          .then((file) => file.open(mode: FileMode.writeOnlyAppend))
          .then((raf) => raf.writeFrom(const []))
          .then(_flush);

  /// 平台路径覆盖安装后调用，避免静态初始化过早锁定日志路径。
  static void reset() => _future = null;

  JsonFileHandler._({
    this.enableDeviceParameters = true,
    this.enableApplicationParameters = true,
    this.enableStackTrace = true,
    this.enableCustomParameters = true,
    this.printLogs = false,
    this.handleWhenRejected = false,
  });

  static Future<JsonFileHandler?> init({
    bool enableDeviceParameters = true,
    bool enableApplicationParameters = true,
    bool enableStackTrace = true,
    bool enableCustomParameters = true,
    bool printLogs = false,
    bool handleWhenRejected = false,
  }) async {
    try {
      await _ensureFuture();
      return JsonFileHandler._(
        enableDeviceParameters: enableDeviceParameters,
        enableApplicationParameters: enableApplicationParameters,
        enableStackTrace: enableStackTrace,
        enableCustomParameters: enableCustomParameters,
        printLogs: printLogs,
        handleWhenRejected: handleWhenRejected,
      );
    } catch (e, s) {
      logger.e('Init log file', error: e, stackTrace: s);
      return null;
    }
  }

  static Future<RandomAccessFile> _flush(RandomAccessFile raf) => raf.flush();

  static Future<RandomAccessFile> add(
    Future<RandomAccessFile> Function(RandomAccessFile) onValue,
  ) {
    return _future = _ensureFuture().then(onValue).then(_flush);
  }

  @override
  Future<bool> handle(Report report) async {
    try {
      await _processReport(report);
      return true;
    } catch (exc, stackTrace) {
      logger.e(
        'Write Json Exception occurred',
        error: exc,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<void> _processReport(Report report) {
    if (printLogs) {
      logger.d('Writing report to file');
    }
    final json = report.toJson(
      enableDeviceParameters: enableDeviceParameters,
      enableApplicationParameters: enableApplicationParameters,
      enableStackTrace: enableStackTrace,
      enableCustomParameters: enableCustomParameters,
    );
    return add((raf) => raf.writeString('${jsonEncode(json)}\n'));
  }
}
