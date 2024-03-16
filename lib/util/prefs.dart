// SPDX-License-Identifier: AGPL-3.0-only

import 'package:shared_preferences/shared_preferences.dart';

abstract class Prefs {
  static late final SharedPreferences instance;

  static Future<void> init() async {
    instance = await SharedPreferences.getInstance();
  }
}
