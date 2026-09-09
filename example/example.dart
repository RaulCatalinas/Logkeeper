import 'package:intl/intl.dart';
import 'package:logkeeper/log_level.dart';
import 'package:logkeeper/logkeeper.dart';

/// Example of how to use LogKeeper.
///
/// LogKeeper is a plug-and-play file logger for Dart and Flutter.
/// It works out of the box, no configuration required.
void main() async {
  // ─────────────────────────────────────────────
  // 1️⃣ SIMPLEST USAGE (NO CONFIGURATION NEEDED)
  // ─────────────────────────────────────────────
  //
  // LogKeeper works perfectly without any setup.
  // Just import and start logging!
  LogKeeper.info('Application started');
  LogKeeper.warning('Low disk space detected');
  LogKeeper.error('Failed to fetch user data');
  LogKeeper.critical('Unexpected system failure');

  // ─────────────────────────────────────────────
  // 2️⃣ OPTIONAL CONFIGURATION (IF YOU NEED IT)
  // ─────────────────────────────────────────────
  //
  // If you want to customize behavior, call configure()
  // BEFORE any logging operations (first line in main).

  LogKeeper.configure(
    logDirectory: 'custom_logs',
    minLevelForProduction: LogLevel.warning,
    fileNameDateFormat: DateFormat('yyyy_MM_dd-HH_mm'),
    timestampFormat: DateFormat('HH:mm:ss.SSS'),
    maxLogAgeDays: 7,
    writeToFileInDevMode: true,
    colorizeConsoleOutput: false,
  );

  LogKeeper.info('More logging examples');
  LogKeeper.warning('Custom logging directory active');
  LogKeeper.error('Simulated error event');
  LogKeeper.critical('Simulated critical issue');

  // ─────────────────────────────────────────────
  // 3️⃣ LOG DIRECTORY PATH (OPTIONAL)
  // ─────────────────────────────────────────────
  //
  // Use LogKeeper.ensureLogDirectoryPath() when you need a non-null absolute
  // path before relying on other code paths. It initializes the same internal
  // state as the first log line would (safe to call multiple times).
  final logDirAbsolute = await LogKeeper.ensureLogDirectoryPath();
  print('Log directory (from ensure): $logDirAbsolute');

  // LogKeeper.logDirectoryPath is a synchronous read of that folder once it
  // exists—after LogKeeper.configure with logDirectory, after
  // ensureLogDirectoryPath, or after at least one log call.
  print('Log directory (getter): ${LogKeeper.logDirectoryPath}');

  // ─────────────────────────────────────────────
  // 4️⃣ PERIODIC FLUSHING (E.G. MOBILE APP LIFECYCLE)
  // ─────────────────────────────────────────────
  //
  // Unlike saveLogs(), flushLogs() writes buffered entries to disk
  // WITHOUT closing the underlying sink — safe to call as many times
  // as needed throughout the app's lifetime.
  //
  // Typical use: a mobile app that may be killed by the OS at any
  // moment without warning. Call flushLogs() every time the app
  // moves to the background, so buffered logs aren't lost even if
  // the process never gets a chance to exit cleanly.
  LogKeeper.info('App moved to background');
  await LogKeeper.flushLogs();

  LogKeeper.info('App resumed');
  LogKeeper.warning('Something worth noting happened');
  await LogKeeper.flushLogs(); // safe to call again

  // ─────────────────────────────────────────────
  // 5️⃣ CLEANUP AND SHUTDOWN
  // ─────────────────────────────────────────────
  //
  // Call saveLogs() once, right before the app truly exits, to do
  // a final flush and close the sink. After this, flushLogs() should
  // not be called again.
  await LogKeeper.saveLogs();

  print('✅ Logs saved successfully!');
}
