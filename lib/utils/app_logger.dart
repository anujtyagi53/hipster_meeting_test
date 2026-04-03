import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:hipster_meeting_test/config/env_config.dart';

enum LogLevel { debug, info, warning, error, fatal }

class AppLogger {
  static void log(
    String message, {
    LogLevel level = LogLevel.info,
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final prefix = tag != null ? '[$tag]' : '';
    final logEntry = '[$timestamp][${level.name.toUpperCase()}]$prefix $message';

    if (EnvConfig.isProduction && level == LogLevel.debug) return;

    if (kDebugMode) {
      developer.log(
        logEntry,
        name: 'HipsterMeet',
        error: error,
        stackTrace: stackTrace,
        level: _levelToInt(level),
      );
    }
  }

  static void debug(String message, {String? tag}) =>
      log(message, level: LogLevel.debug, tag: tag);

  static void info(String message, {String? tag}) =>
      log(message, level: LogLevel.info, tag: tag);

  static void warning(String message, {String? tag}) =>
      log(message, level: LogLevel.warning, tag: tag);

  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) =>
      log(message, level: LogLevel.error, tag: tag, error: error, stackTrace: stackTrace);

  static void fatal(String message, {String? tag, Object? error, StackTrace? stackTrace}) =>
      log(message, level: LogLevel.fatal, tag: tag, error: error, stackTrace: stackTrace);

  static int _levelToInt(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
      case LogLevel.fatal:
        return 1200;
    }
  }
}
