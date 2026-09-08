import 'log_level.dart' show LogLevel;

const Map<LogLevel, String> colorMap = {
  LogLevel.info: '\x1B[36m',
  LogLevel.warning: '\x1B[33m',
  LogLevel.error: '\x1B[31m',
  LogLevel.critical: '\x1B[95m'
};

const String resetColor = '\x1B[0m';
