import 'dart:io' show Directory, File;

import 'package:flutter_test/flutter_test.dart'
    show
        TestWidgetsFlutterBinding,
        contains,
        equals,
        expect,
        group,
        isFalse,
        isNot,
        isNotEmpty,
        isNull,
        isTrue,
        tearDown,
        test;
import 'package:intl/intl.dart' show DateFormat;
import 'package:logkeeper/logkeeper.dart' show LogKeeper;
import 'package:logkeeper/src/logkeeper.dart' show resetLogKeeperForTesting;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart'
    show PathProviderPlatform;

import 'test_utils.dart' show clearDirectory, FakePathProviderPlatform;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PathProviderPlatform.instance = FakePathProviderPlatform();

  const String testDir = 'test_logs';

  group('LogKeeper', () {
    tearDown(() async {
      await resetLogKeeperForTesting();
      await clearDirectory('logs');
      await clearDirectory(testDir);
    });

    group('writing logs', () {
      test('creates log directory if it does not exist when writing to file',
          () async {
        LogKeeper.configure(
          logDirectory: testDir,
          writeToFileInDevMode: true,
        );

        LogKeeper.info('Test message');
        await LogKeeper.saveLogs();

        expect(await Directory(testDir).exists(), isTrue);
      });

      test('does not write to file in dev mode by default', () async {
        LogKeeper.info('Should not be written');
        await LogKeeper.saveLogs();

        final dir = Directory('logs');
        if (await dir.exists()) {
          final files = dir
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.log'))
              .toList();

          if (files.isEmpty) {
            final content = await files.first.readAsString();
            expect(content.trim().isEmpty, isTrue);
          }
        }
      });

      test('writes to custom directory when configured', () async {
        LogKeeper.configure(
          logDirectory: testDir,
          writeToFileInDevMode: true,
        );

        LogKeeper.info('Test message');
        await LogKeeper.saveLogs();

        expect(await Directory(testDir).exists(), isTrue);

        final files = Directory(testDir)
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.log'))
            .toList();

        expect(files.isNotEmpty, isTrue);

        final content = await files.first.readAsString();
        expect(content.contains('Test message'), isTrue);
      });

      test('writes all log levels with correct labels', () async {
        LogKeeper.configure(
          logDirectory: testDir,
          writeToFileInDevMode: true,
        );

        LogKeeper.info('Info message');
        LogKeeper.warning('Warning message');
        LogKeeper.error('Error message');
        LogKeeper.critical('Critical message');
        await LogKeeper.saveLogs();

        final file = Directory(testDir).listSync().whereType<File>().first;
        final content = await file.readAsString();

        expect(content.contains('INFO: Info message'), isTrue);
        expect(content.contains('WARNING: Warning message'), isTrue);
        expect(content.contains('ERROR: Error message'), isTrue);
        expect(content.contains('CRITICAL: Critical message'), isTrue);
      });
    });

    group('directory path', () {
      test('logDirectoryPath is null before initialization', () {
        expect(LogKeeper.logDirectoryPath, isNull);
      });

      test('ensureLogDirectoryPath initializes and returns a non-null path',
          () async {
        final path = await LogKeeper.ensureLogDirectoryPath();

        expect(path, isNotEmpty);
        expect(LogKeeper.logDirectoryPath, equals(path));
      });
    });

    group('custom formatting', () {
      test('applies custom file name format', () async {
        LogKeeper.configure(
          logDirectory: testDir,
          fileNameDateFormat: DateFormat('yyyyMMdd_HHmm'),
          writeToFileInDevMode: true,
        );

        LogKeeper.info('Test');
        await LogKeeper.saveLogs();

        final files = Directory(testDir).listSync().whereType<File>().toList();
        expect(files.isNotEmpty, isTrue);

        final fileName = files.first.path;
        expect(fileName.contains(RegExp(r'\d{8}_\d{4}\.log')), isTrue);
      });

      test('applies custom timestamp format', () async {
        LogKeeper.configure(
          logDirectory: testDir,
          timestampFormat: DateFormat('HH:mm:ss.SSS'),
          writeToFileInDevMode: true,
        );

        LogKeeper.info('Test');
        await LogKeeper.saveLogs();

        final file = Directory(testDir).listSync().whereType<File>().first;
        final content = await file.readAsString();

        expect(
          content.contains(RegExp(r'\[\d{2}:\d{2}:\d{2}\.\d{3}\]')),
          isTrue,
        );
      });

      test('applies multiple custom formats simultaneously', () async {
        LogKeeper.configure(
          logDirectory: testDir,
          fileNameDateFormat: DateFormat('yyyy-MM-dd'),
          timestampFormat: DateFormat('yyyy-MM-dd HH:mm:ss'),
          writeToFileInDevMode: true,
        );

        LogKeeper.info('Multi format test');
        await LogKeeper.saveLogs();

        final files = Directory(testDir).listSync().whereType<File>().toList();
        expect(files.isNotEmpty, isTrue);

        final fileName = files.first.path;
        expect(fileName.contains(RegExp(r'\d{4}-\d{2}-\d{2}\.log')), isTrue);

        final content = await files.first.readAsString();
        expect(
          content.contains(RegExp(r'\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]')),
          isTrue,
        );
      });
    });

    group('configure lock', () {
      test('configure() after the first write is ignored', () async {
        LogKeeper.configure(
          logDirectory: testDir,
          writeToFileInDevMode: true,
        );
        LogKeeper.info('First');
        await LogKeeper.saveLogs();

        LogKeeper.configure(
          logDirectory: 'other_dir',
          writeToFileInDevMode: true,
        );

        expect(LogKeeper.logDirectoryPath, isNot(contains('other_dir')));
      });
    });

    group('log retention', () {
      test('deletes old log files when maxLogAgeDays is set', () async {
        final oldDir = Directory(testDir);
        await oldDir.create(recursive: true);

        final oldFile = File('${oldDir.path}/old.log');
        await oldFile.writeAsString('Old log');
        await oldFile.setLastModified(
          DateTime.now().subtract(const Duration(days: 10)),
        );

        LogKeeper.configure(
          logDirectory: testDir,
          maxLogAgeDays: 7,
          writeToFileInDevMode: true,
        );

        LogKeeper.info('New log');
        await LogKeeper.saveLogs();

        final files = oldDir.listSync().whereType<File>().toList();
        expect(files.any((f) => f.path.endsWith('old.log')), isFalse);
      });
    });

    group('saveLogs vs flushLogs', () {
      test('flushLogs writes to disk without closing the sink', () async {
        LogKeeper.configure(
          logDirectory: testDir,
          writeToFileInDevMode: true,
        );

        LogKeeper.info('First message');
        await LogKeeper.flushLogs();

        var files = Directory(testDir).listSync().whereType<File>().toList();
        expect(files.isNotEmpty, isTrue);

        var content = await files.first.readAsString();
        expect(content.contains('First message'), isTrue);

        LogKeeper.info('Second message');
        await LogKeeper.flushLogs();

        files = Directory(testDir).listSync().whereType<File>().toList();
        content = await files.first.readAsString();

        expect(content.contains('First message'), isTrue);
        expect(content.contains('Second message'), isTrue);
      });

      test('flushLogs does not prevent a later saveLogs call', () async {
        LogKeeper.configure(
          logDirectory: testDir,
          writeToFileInDevMode: true,
        );

        LogKeeper.info('Before flush');
        await LogKeeper.flushLogs();

        LogKeeper.info('Before save');
        await LogKeeper.saveLogs();

        final files = Directory(testDir).listSync().whereType<File>().toList();
        final content = await files.first.readAsString();

        expect(content.contains('Before flush'), isTrue);
        expect(content.contains('Before save'), isTrue);
      });
    });

    group('write failure resilience', () {
      test('a failed write does not break subsequent writes', () async {
        final blockingFile = File(testDir);
        await blockingFile.writeAsString('not a directory');

        LogKeeper.configure(
          logDirectory: testDir,
          writeToFileInDevMode: true,
        );

        LogKeeper.info('This write should fail');
        await LogKeeper.flushLogs();

        await blockingFile.delete();

        LogKeeper.info('This write should succeed');
        await LogKeeper.saveLogs();

        final files = Directory(testDir).listSync().whereType<File>().toList();
        expect(files.isNotEmpty, isTrue);

        final content = await files.first.readAsString();
        expect(content.contains('This write should succeed'), isTrue);
        expect(content.contains('This write should fail'), isFalse);
      });
    });
  });
}
