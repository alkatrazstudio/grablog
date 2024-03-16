// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

class StringListNotifier extends ValueNotifier<List<String>> {
  StringListNotifier(): super([]);

  void addString(String s) {
    value.add(s);
    notifyListeners();
  }
}

class LogOutputNotifier extends LogOutput {
  var notifier = StringListNotifier();

  @override
  void output(OutputEvent event) async {
    for(var line in event.lines)
      notifier.addString(line);
  }
}

class LogFilterAll extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    return true;
  }
}

abstract class Log {
  static final printer = PrettyPrinter(
    errorMethodCount: 5,
    methodCount: 0,
    noBoxingByDefault: true,
    lineLength: 13371337,
    printEmojis: false,
    colors: false,
  );

  static final consoleLogger = Logger(
    printer: printer,
    filter: LogFilterAll()
  );

  static var notifierOutput = LogOutputNotifier();

  static final notifierLogger = Logger(
    printer: printer,
    filter: LogFilterAll(),
    output: notifierOutput
  );

  static String format(String s, String level) {
    var dateStr = DateFormat('yyyy-MM-dd kk:mm:ss').format(DateTime.now());
    return '[$dateStr] [$level] $s';
  }

  static StringListNotifier get notifier => notifierOutput.notifier;

  static void info(String s) {
    var msg = format(s, 'INFO ');
    consoleLogger.i(msg);
    notifierLogger.i(msg);
  }

  static void warn(String s) {
    var msg = format(s, 'WARN ');
    consoleLogger.w(msg);
    notifierLogger.w(msg);
  }

  static void error(String s) {
    var msg = format(s, 'ERROR');
    consoleLogger.e(msg, error: s);
    notifierLogger.e(msg, error: s);
  }

  static void exception(Object e, String extraContext) {
    var msg = e.toString();
    if(extraContext.isNotEmpty)
      msg = '$extraContext: $msg';
    error(msg);
  }
}
