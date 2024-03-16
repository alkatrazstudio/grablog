// SPDX-License-Identifier: AGPL-3.0-only

import 'package:args/args.dart';

class CliArgs {
  CliArgs(List<String> args) {
    var parser = ArgParser();
    var results = parser.parse(args);
    path = results.rest.firstOrNull;
  }

  late final String? path;
}
