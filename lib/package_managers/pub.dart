// SPDX-License-Identifier: AGPL-3.0-only

import 'package:collection/collection.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

import '../common/package.dart';
import '../common/package_manager.dart';
import '../util/downloader.dart';
import '../util/logger.dart';

class PubLockEntry extends LockEntry {
  PubLockEntry({
    required super.name,
    required super.versionSpec,
    required super.meta,
    required super.isDev,
    required this.pubUrl
  });

  final String pubUrl;
}

class PubPackage extends Package {
  PubPackage({
    required super.name,
    required super.version,
    required super.constraintStr,
    required super.constraint,
    required super.isDev,
    required super.infoUrl,
    required this.pubUrl
  });

  final String? pubUrl;

  @override
  Future<RepoPackage> fetchRepoPackage(String infoUrl) async {
    var info = await Downloader.getJsonObject(infoUrl);
    var latest = info['latest'] as Map<String, dynamic>;
    var pubspec = latest['pubspec'] as Map<String, dynamic>;
    var versions = <PackageVersion>[];
    for(var (index, versionItem) in (info['versions'] as List<dynamic>).indexed) {
      try {
        var versionMap = versionItem as Map<String, dynamic>;
        var version = Version.parse(versionMap['version'] as String);
        var releasedAt = DateTime.parse(versionMap['published'] as String);
        versions.add(PackageVersion(version: version, releasedAt: releasedAt));
      } catch(e) {
        logException(e, '$infoUrl > versions[$index]');
      }
    }

    var links = <PackageLink>[];
    if(pubUrl != null) {
      links.add(PackageLink(
        name: 'Pub',
        url: '$pubUrl/packages/$name',
        isVisibleToUser: false
      ));
    }
    try {
        links.add(PackageLink(
          name: 'Repository',
          url: pubspec['repository'] as String,
          isVisibleToUser: true
        ));
    } catch(e) {
      logException(e, 'fetching repository link');
    }

    return RepoPackage(
      links: links,
      versions: versions
    );
  }
}

class Pub extends PackageManager {
  Pub({
    required super.filename,
    required super.projectName,
    required super.packages
  }): super(name: 'Pub');

  static Future<Pub?> fromDirOrFile(String path) async {
    var files = await PackageManager.loadPackagesAndLockFiles(path, 'pubspec.lock', 'pubspec.yaml');
    if(files == null)
      return null;
    var (lockFilename, lockYaml, packagesYaml) = files;

    var packagesMap = loadYaml(packagesYaml);
    var projectName = (packagesMap['name'] as String?) ?? '';
    var lockMap = loadYaml(lockYaml);
    var lockEntries = await extractLockEntries(lockMap);
    var packagesDist = extractPackageEntries(packagesMap, false);
    var packagesDev = extractPackageEntries(packagesMap, true);
    var packageEntries = packagesDist + packagesDev;

    var packages = packageEntries.map((packageEntry) {
      var lockEntry = lockEntries.firstWhereOrNull(
        (lockEntry) => lockEntry.name == packageEntry.name && lockEntry.isDev == packageEntry.isDev
      );
      var package = PubPackage(
        name: packageEntry.name,
        version: lockEntry?.meta.version,
        constraintStr: packageEntry.constraintStr,
        constraint: packageEntry.constraint,
        isDev: packageEntry.isDev,
        infoUrl: lockEntry?.meta.infoUrl,
        pubUrl: lockEntry?.pubUrl
      );
      return package;
    }).toList();

    var manager = Pub(
      filename: lockFilename,
      projectName: projectName,
      packages: packages
    );
    return manager;
  }

  static Future<List<PubLockEntry>> extractLockEntries(YamlMap lockMap) async {
    var entries = <PubLockEntry>[];
    var packageItems = lockMap['packages'] ?? YamlMap();
    for(var packageItem in packageItems.entries) {
      var dependencyFlags = ((packageItem.value['dependency'] as String?) ?? '').split(' ');
      if(!dependencyFlags.contains('direct'))
        continue;

      var isDev = dependencyFlags.contains('dev');
      var packageName = packageItem.key;
      var packageMap = packageItem.value;
      String pubUrl;
      try {
        pubUrl = packageMap['description']['url'] as String;
      } catch(e) {
        Log.exception(e, 'Package $packageName${isDev ? ' (dev)' : ''}, fetching description URL');
        continue;
      }
      Version? version;
      try {
        var versionToParse = packageMap['version'] as String;
        version = Version.parse(versionToParse);
      } catch(e) {
        Log.exception(e, 'Package $packageName${isDev ? ' (dev)' : ''}, fetching version');
      }

      var lockMeta = LockEntryMeta(
        version: version,
        infoUrl: '$pubUrl/api/packages/$packageName'
      );
      var entry = PubLockEntry(
        name: packageName,
        versionSpec: '',
        meta: lockMeta,
        isDev: isDev,
        pubUrl: pubUrl
      );
      entries.add(entry);
    }
    return entries;
  }

  static List<PackageEntry> extractPackageEntries(YamlMap packagesMap, bool isDev) {
    var entries = <PackageEntry>[];
    var packagesKey = isDev ? 'dev_dependencies' : 'dependencies';
    var packagesItems = packagesMap[packagesKey];
    if(packagesItems == null)
      return [];
    for(var packageItem in packagesItems.entries) {
      var packageName = packageItem.key;
      if(packageName == 'flutter')
        continue;

      String constraintStr;
      try {
        constraintStr = (packageItem.value as String?) ?? '';
      } catch(e) {
        try {
          var packageMap = packageItem.value ?? YamlMap();
          constraintStr = packageMap['version'];
        } catch(e) {
          constraintStr = '';
          Log.exception(e, 'Package $packageName${isDev ? ' (dev)' : ''}, fetching constraint');
        }
      }
      VersionConstraint? constraint;
      try {
        constraint = VersionConstraint.parse(constraintStr);
      } catch(e) {
        Log.exception(e, 'Package $packageName${isDev ? ' (dev)' : ''}, parsing version constraint');
      }

      var entry = PackageEntry(
        name: packageName,
        constraintStr: constraintStr,
        constraint: constraint,
        isDev: isDev
      );
      entries.add(entry);
    }
    return entries;
  }
}
