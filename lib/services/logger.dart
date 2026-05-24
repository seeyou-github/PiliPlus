import 'dart:io';

import 'package:PiliPlus/utils/json_file_handler.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:catcher_2/catcher_2.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final logger = PiliLogger();

class PiliLogger extends Logger {
  PiliLogger() : super();

  @override
  void log(
    Level level,
    dynamic message, {
    Object? error,
    StackTrace? stackTrace,
    DateTime? time,
  }) {
    if (!_enableLog) return;
    LoggerUtils.writeTextLog(
      level: level,
      message: message,
      error: error,
      stackTrace: stackTrace,
      time: time,
    );
    if (level == Level.error || level == Level.fatal) {
      Catcher2.reportCheckedError(error, stackTrace);
    }
    super.log(level, message, error: error, stackTrace: stackTrace, time: time);
  }

  bool get _enableLog {
    try {
      return Pref.enableLog;
    } catch (_) {
      return false;
    }
  }
}

abstract final class LoggerUtils {
  static File? _logFile;
  static File? _textLogFile;

  static Future<File> getLogsPath() async {
    if (_logFile != null) return _logFile!;

    String dir = await _logDir();
    final String filename = p.join(dir, '.pili_logs.json');
    final File file = File(filename);
    if (!file.existsSync()) {
      await file.create(recursive: true);
    }
    return _logFile = file;
  }

  static Future<String> _logDir() async {
    if (PlatformUtils.isDesktop) {
      return File(Platform.resolvedExecutable).parent.path;
    }
    return (await getApplicationDocumentsDirectory()).path;
  }

  static Future<File> getTextLogPath() async {
    if (_textLogFile != null) return _textLogFile!;

    final file = File(p.join(await _logDir(), 'pili_debug.log'));
    if (!file.existsSync()) {
      await file.create(recursive: true);
    }
    return _textLogFile = file;
  }

  static Future<void> writeTextLog({
    required Level level,
    required dynamic message,
    Object? error,
    StackTrace? stackTrace,
    DateTime? time,
  }) async {
    try {
      final dateTime = (time ?? DateTime.now()).toIso8601String();
      final buffer = StringBuffer()
        ..write(dateTime)
        ..write(' [')
        ..write(level.name.toUpperCase())
        ..write('] ')
        ..write(message);
      if (error != null) {
        buffer
          ..write(' | error: ')
          ..write(error);
      }
      if (stackTrace != null) {
        buffer
          ..write('\n')
          ..write(stackTrace);
      }
      buffer.write('\n');
      final file = await getTextLogPath();
      await file.writeAsString(buffer.toString(), mode: FileMode.append);
    } catch (_) {}
  }

  static Future<bool> clearLogs() async {
    try {
      if (Pref.enableLog) {
        await JsonFileHandler.add(
          (raf) => raf.setPosition(0).then((raf) => raf.truncate(0)),
        );
      } else {
        final file = await getLogsPath();
        await file.writeAsBytes(const [], flush: true);
      }
      final textFile = await getTextLogPath();
      await textFile.writeAsBytes(const [], flush: true);
    } catch (e) {
      // if (kDebugMode) debugPrint('Error clearing file: $e');
      return false;
    }
    return true;
  }
}
