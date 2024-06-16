// SPDX-License-Identifier: AGPL-3.0-only

import 'package:args/args.dart';
import 'package:path/path.dart';

class CliArgs {
  CliArgs(List<String> args) {
    var parser = ArgParser();
    var results = parser.parse(args);
    var argPath = results.rest.firstOrNull;
    if(argPath != null)
      argPath = absolute(argPath);
    path = argPath;
  }

  late final String? path;
}
