// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:window_manager/window_manager.dart';

import '../util/cli_args.dart';
import '../util/logger.dart';
import '../util/prefs.dart';
import '../widgets/home.dart';

class App extends StatelessWidget {
  const App(this.cliArgs);

  final CliArgs cliArgs;

  static String extractVersionLine(PackageInfo packageInfo) {
    var version = packageInfo.version;
    var appVersionLine = 'GrabLog v$version';
    var appBuildTimestamp = const int.fromEnvironment('APP_BUILD_TIMESTAMP');
    if(appBuildTimestamp != 0) {
      var dateStr = DateFormat.yMMMMd().format(DateTime.fromMillisecondsSinceEpoch(appBuildTimestamp * 1000));
      appVersionLine = '$appVersionLine ($dateStr)';
    }
    return appVersionLine;
  }

  static String get gitHash => const String.fromEnvironment('APP_GIT_HASH');

  @override
  Widget build(context) {
    var lightScheme = ColorScheme.fromSeed(
      seedColor: Colors.lime,
      primary: Colors.lime,
      secondary: Colors.orange.shade200,
      brightness: Brightness.light
    );
    var darkScheme = ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      primary: Colors.deepPurple,
      secondary: Colors.blueGrey,
      brightness: Brightness.dark,
    );

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.noScaling,
      ),
      child: MaterialApp(
        title: 'GrabLog',
        theme: ThemeData(
          brightness: Brightness.light,
          colorScheme: lightScheme,
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(foregroundColor: lightScheme.onPrimaryContainer)
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: lightScheme.onPrimaryContainer)
          )
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: darkScheme,
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(foregroundColor: darkScheme.onPrimaryContainer)
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: darkScheme.onPrimaryContainer)
          )
        ),
        home: Home(cliArgs),
      )
    );
  }

  static Future<void> initWindowManager() async {
    try {
      await windowManager.ensureInitialized();
      var windowOptions = const WindowOptions(
        title: 'GrabLog',
        minimumSize: Size(900, 400)
      );
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        try {
          await windowManager.show();
          await windowManager.focus();
        } catch(e) {
          Log.exception(e, 'showing window');
        }
      });
    } catch(e) {
      Log.exception(e, 'initializing window manager');
    }
  }

  static void run(List<String> args) async {
    Log.info('app start');
    WidgetsFlutterBinding.ensureInitialized();
    await Prefs.init();
    await initWindowManager();
    Log.info(extractVersionLine(await PackageInfo.fromPlatform()));
    Log.info('Git hash: $gitHash');
    Log.info('current dir: ${Directory.current.path}');
    Log.info('args: ${args.join(' ')}');
    var cliArgs = CliArgs(args);
    Log.info('window manager initialized');
    runApp(ProviderScope(
      child: App(cliArgs)
    ));
  }
}
