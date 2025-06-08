// SPDX-License-Identifier: AGPL-3.0-only

import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences/util/legacy_to_async_migration_util.dart';

abstract class Prefs {
  static late final SharedPreferencesWithCache instance;

  static Future<void> init() async {
    await migrateLegacySharedPreferencesToSharedPreferencesAsyncIfNecessary(
        legacySharedPreferencesInstance: await SharedPreferences.getInstance(),
        sharedPreferencesAsyncOptions: const SharedPreferencesOptions(),
        migrationCompletedKey: 'migrationCompleted'
    );

    instance = await SharedPreferencesWithCache.create(cacheOptions: const SharedPreferencesWithCacheOptions());
  }
}
