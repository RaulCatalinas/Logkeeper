import 'dart:io' show Directory;

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:intl/intl.dart' show DateFormat;
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart'
    show getApplicationSupportDirectory;

import 'constants.dart' show colorMap, resetColor;
import 'file_manager.dart' show FileManager;
import 'log_level.dart' show LogLevel;

class LogKeeper {
  static final LogKeeper _instance = LogKeeper._internal();
  DateFormat _timestampFormatter = DateFormat.Hms();
  DateFormat _filenameFormatter = DateFormat('yyyy-MM-dd_HH-mm-ss');
  Directory? _logDir;
  LogLevel _minLevelForProduction = LogLevel.info;
  bool _writeToFileInDevMode = false;
  int? _maxLogAgeDays;
  bool _colorizeConsoleOutput = true;
  FileManager? _fileManager;

  factory LogKeeper() => _instance;

  LogKeeper._internal();

  /// Absolute filesystem path of the directory where log files are written.
  ///
  /// Returns `null` until [configure] sets `logDirectory`, or until
  /// [ensureLogDirectoryPath] or the first log write initializes the default
  /// application support `logs` folder.
  static String? get logDirectoryPath => _instance._logDir?.absolute.path;

  /// Resolves the log directory and returns its absolute path.
  ///
  /// Unlike [logDirectoryPath], this never returns null: if no directory was
  /// configured yet, it awaits the default application support `logs` folder
  /// and initializes the internal [FileManager] the same way the first log
  /// write would.
  static Future<String> ensureLogDirectoryPath() async {
    await _ensureInitialized();
    return _instance._logDir!.absolute.path;
  }

  /// Optional configuration for LogKeeper.
  ///
  /// **Completely optional** - LogKeeper works perfectly with defaults.
  ///
  /// ⚠️ **If you use it**: Call as the first line in `main()`, before any logging.
  ///
  /// Example:
  /// ```dart
  /// void main() async {
  ///   LogKeeper.configure(
  ///     logDirectory: 'app_logs',
  ///     maxLogAgeDays: 7,
  ///   );
  ///   LogKeeper.info('App started');
  ///   await LogKeeper.saveLogs();
  /// }
  /// `
  static void configure({
    String? logDirectory,
    LogLevel? minLevelForProduction,
    int? maxLogAgeDays,
    DateFormat? fileNameDateFormat,
    DateFormat? timestampFormat,
    bool? writeToFileInDevMode,
    bool? colorizeConsoleOutput,
  }) {
    if (logDirectory != null) {
      _instance._logDir = Directory(logDirectory);
    }

    _instance._minLevelForProduction = minLevelForProduction ?? LogLevel.info;
    _instance._maxLogAgeDays = maxLogAgeDays;
    _instance._filenameFormatter =
        fileNameDateFormat ?? DateFormat('yyyy-MM-dd_HH-mm-ss');
    _instance._timestampFormatter = timestampFormat ?? DateFormat.Hms();
    _instance._writeToFileInDevMode = writeToFileInDevMode ?? false;
    _instance._colorizeConsoleOutput = colorizeConsoleOutput ?? true;
  }

  static Future<void> _ensureInitialized() async {
    _instance._logDir ??= await _getDefaultLogsDir();
    _instance._fileManager ??= FileManager(
      logDir: _instance._logDir!,
      filenameFormatter: _instance._filenameFormatter,
      maxLogAgeDays: _instance._maxLogAgeDays,
      createNewFile: kReleaseMode || _instance._writeToFileInDevMode,
    );
  }

  static Future<void> _writeLog(LogLevel level, String message) async {
    await _ensureInitialized();

    final timestamp = _instance._timestampFormatter.format(DateTime.now());
    final logEntry = '[$timestamp] ${level.toString()}: $message';

    final shouldWriteToFile = kReleaseMode
        ? level.value >= _instance._minLevelForProduction.value
        : _instance._writeToFileInDevMode;

    if (!kReleaseMode) {
      print(
        _instance._colorizeConsoleOutput
            ? _colorize(message: logEntry, level: level)
            : logEntry,
      );
    }

    if (shouldWriteToFile) {
      _instance._fileManager!.write(logEntry);
    }
  }

  static String _colorize({required String message, required LogLevel level}) {
    return '${colorMap[level]}$message$resetColor';
  }

  /// Logs an informational message.
  ///
  /// Use this for general information about application flow and state.
  ///
  /// Example:
  /// ```dart
  ///   LogKeeper.info('User logged in successfully');
  ///   LogKeeper.info('Database connection established');
  /// ```
  ///
  static void info(String message) => _writeLog(LogLevel.info, message);

  /// Logs a warning message.
  ///
  /// Use this for potentially harmful situations that don't prevent the application from functioning.
  ///
  /// Example:
  /// ```dart
  ///   LogKeeper.warning('Disk space running low');
  ///   LogKeeper.warning('API rate limit approaching');
  /// ````
  ///
  static void warning(String message) => _writeLog(LogLevel.warning, message);

  /// Logs an error message.
  ///
  /// Use this for error events that might still allow the application to continue running.
  ///
  /// Example:
  /// ```dart
  ///   LogKeeper.error('Failed to fetch user data');
  ///   LogKeeper.error('Network connection timeout');
  /// ```
  ///
  static void error(String message) => _writeLog(LogLevel.error, message);

  /// Logs a critical message.
  ///
  /// Use this for severe error events that will presumably lead the application to abort or require immediate attention.
  ///
  /// Example:
  /// ```dart
  ///   LogKeeper.critical('Database corruption detected');
  ///   LogKeeper.critical('Out of memory error');
  /// ```
  ///
  static void critical(String message) => _writeLog(LogLevel.critical, message);

  /// Flushes and closes the log file.
  ///
  /// This method should be called when you're done logging, typically before the application exits.
  ///
  /// It ensures all buffered log entries are written to disk and the file handle is properly closed.
  ///
  /// Example:
  ///  ```dart
  ///   void main() async {
  ///     LogKeeper.info('Application starting');
  ///     // ... application logic ...
  ///     LogKeeper.info('Application shutting down');
  ///     await LogKeeper.saveLogs();
  ///   }
  /// ```
  ///
  /// Returns a [Future] that completes when the log file has been flushed and closed.
  static Future<void> saveLogs() async => await _instance._fileManager?.close();

  /// Writes any buffered log entries to disk without closing the
  /// underlying file sink.
  ///
  /// Unlike [saveLogs], which closes the sink after writing (and is meant
  /// to be called once, right before the app truly exits), [flushLogs] can
  /// be called safely as many times as needed throughout the app's
  /// lifetime — for example, on each transition to the background, or
  /// right after a [LogKeeper.critical] call, to reduce the risk of losing
  /// buffered entries if the process is later killed without warning.
  static Future<void> flushLogs() async =>
      await _instance._fileManager?.flush();

  static Future<Directory> _getDefaultLogsDir() async {
    final dir = await getApplicationSupportDirectory();

    return Directory(join(dir.path, 'logs'));
  }
}
