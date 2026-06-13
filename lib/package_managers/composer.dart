// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:pub_semver/pub_semver.dart';

import '../common/package.dart';
import '../common/package_manager.dart';
import '../util/downloader.dart';
import '../util/logger.dart';

class ComposerPackage extends Package {
  ComposerPackage({
    required super.name,
    required super.version,
    required super.constraintStr,
    required super.constraint,
    required super.isDev,
    required super.infoUrl
  });

  @override
  Future<RepoPackage> fetchRepoPackage(String infoUrl) async {
    var info = await Downloader.getJsonObject(infoUrl);
    var bannedConstraints = extractBannedConstraints(info, infoUrl);
    var versions = info['packages'][name] as List<dynamic>;
    var versionObjs = <PackageVersion>[];
    for(var (index, versionItem) in versions.indexed) {
      try {
        var versionMap = versionItem as Map<String, dynamic>;
        var versionStr = versionMap['version_normalized'] as String;
        var versionParts = versionStr.split('.');
        versionStr = '${versionParts[0]}.${versionParts[1]}.${versionParts[2]}';
        var version = Version.parse(versionStr);
        if(bannedConstraints.any((c) => c.allows(version)))
          continue;
        var timeStr = versionMap['time'] as String?;
        var releasedAt = timeStr == null ? null : DateTime.tryParse(timeStr);
        var versionObj = PackageVersion(
          version: version,
          releasedAt: releasedAt
        );
        versionObjs.add(versionObj);
      } catch(e) {
        logException(e, '$infoUrl > packages[$name][version_normalized][$index]');
        continue;
      }
    }

    var links = <PackageLink>[];
    links.add(PackageLink(
        name: 'Packagist',
        url: 'https://packagist.org/packages/$name',
        isVisibleToUser: true
    ));
    try {
      var firstVersionItem = versions.first as Map<String, dynamic>;
      try {
        links.add(PackageLink(
          name: 'Source',
          url: (firstVersionItem['source'] as Map<String, dynamic>)['url'] as String,
          isVisibleToUser: false
        ));
      } catch(e) {
        logException(e, 'fetching source link');
      }
      try {
        links.add(PackageLink(
          name: 'Issues',
          url: (firstVersionItem['support'] as Map<String, dynamic>)['issues'] as String,
          isVisibleToUser: false
        ));
      } catch(e) {
        logException(e, 'fetching support link');
      }
    } catch(e) {
      logException(e, 'fetching first version');
    }

    var repoPackage = RepoPackage(
      links: links,
      versions: versionObjs
    );
    return repoPackage;
  }

  List<VersionConstraint> extractBannedConstraints(Map<String, dynamic> info, String infoUrl) {
    var advisories = info['security-advisories'] as List<dynamic>? ?? [];
    var bannedConstraints = <VersionConstraint>[];
    for(var (index, advisoryItem) in advisories.indexed) {
      try {
        var advisory = advisoryItem as Map<String, dynamic>;
        var constraintStr = advisory['affectedVersions'] as String;
        var constraintParts = constraintStr.split('|');
        for(var constraintPart in constraintParts) {
          var constraint = Composer.parseConstraint(constraintPart, name, false);
          if(constraint != null)
            bannedConstraints.add(constraint);
        }
      } catch(e) {
        logException(e, '$infoUrl > security-advisories[$index]');
        continue;
      }
    }
    return bannedConstraints;
  }
}


class Composer extends PackageManager {
  Composer({
    required super.filename,
    required super.projectName,
    required super.packages
  }): super(name: 'Composer');

  static Future<Composer?> fromDirOrFile(String path) async {
    var files = await PackageManager.loadPackagesAndLockFiles(path, 'composer.lock', 'composer.json');
    if(files == null)
      return null;
    var (lockFilename, lockJson, packagesJson) = files;

    var packagesMap = jsonDecode(packagesJson) as Map<String, dynamic>;
    var projectName = (packagesMap['name'] as String?) ?? '';
    var lockMap = jsonDecode(lockJson) as Map<String, dynamic>;
    var lockEntriesDist = extractLockEntries(lockMap, false);
    var lockEntriesDev = extractLockEntries(lockMap, true);
    var lockEntries = lockEntriesDist + lockEntriesDev;
    var packagesDist = extractPackageEntries(packagesMap, false);
    var packagesDev = extractPackageEntries(packagesMap, true);
    var packageEntries = packagesDist + packagesDev;

    var packages = packageEntries.map((packageEntry) {
      var lockEntry = lockEntries.firstWhereOrNull(
        (lockEntry) => lockEntry.name == packageEntry.name && lockEntry.isDev == packageEntry.isDev
      );
      var constraintStr = packageEntry.constraintStr;
      if(constraintStr.startsWith('dev-master#'))
        constraintStr = 'dev-master';
      var package = ComposerPackage(
        name: packageEntry.name,
        version: lockEntry?.meta.version,
        constraintStr: constraintStr,
        constraint: packageEntry.constraint,
        isDev: packageEntry.isDev,
        infoUrl: lockEntry?.meta.infoUrl
      );
      return package;
    }).toList();

    var manager = Composer(
      filename: lockFilename,
      projectName: projectName,
      packages: packages
    );
    return manager;
  }

  static List<LockEntry> extractLockEntries(Map<String, dynamic> lockMap, bool isDev) {
    var entries = <LockEntry>[];
    var packagesKey = isDev ? 'packages-dev' : 'packages';
    var packageItems = (lockMap[packagesKey] as List<dynamic>?) ?? [];
    for(var packageItem in packageItems) {
      var packageMap = packageItem as Map<String, dynamic>;
      var name = packageMap['name'] as String;

      Version? version;
      try {
        var versionToParse = normalizeVersion(packageMap['version'] as String);
        version = Version.parse(versionToParse);
      } catch(e) {
        Log.exception(e, 'Package: $name${isDev ? ' (dev)' : ''}, parsing version in lock file');
      }
      var lockMeta = LockEntryMeta(
        version: version,
        infoUrl: 'https://repo.packagist.org/p2/$name.json'
      );
      var entry = LockEntry(
        name: name,
        versionSpec: '',
        meta: lockMeta,
        isDev: isDev
      );
      entries.add(entry);
    }
    return entries;
  }

  static List<PackageEntry> extractPackageEntries(Map<String, dynamic> packagesMap, bool isDev) {
    var entries = <PackageEntry>[];
    var packagesKey = isDev ? 'require-dev' : 'require';
    var packagesItems = packagesMap[packagesKey] as Map<String, dynamic>?;
    if(packagesItems == null)
      return [];
    for(var packageItem in packagesItems.entries) {
      var packageName = packageItem.key;
      if(!RegExp(r'^[a-zA-Z0-9_\-]+/[a-zA-Z0-9_\-]+$').hasMatch(packageName))
        continue;
      var constraintStr = (packageItem.value as String?) ?? '';
      var constraint = parseConstraint(constraintStr, packageName, true);
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

  static VersionConstraint? parseConstraint(
    String constraintStr,
    String packageName,
    bool convertExactToUseful
  ) {
    var parts = <String>[];
    var constraintParts = constraintStr.split(',');
    for(var constraintPart in constraintParts) {
      String part;
      if(RegExp(r'^[\^=><]*\d+\.\d+$').hasMatch(constraintPart))
        part = '$constraintPart.0';
      else if(RegExp(r'^[\^=><]*\d+$').hasMatch(constraintPart))
        part = '$constraintPart.0.0';
      else
        part = constraintPart;
      if(part == '*')
        part = 'any';
      if(part.startsWith('='))
        part = part.substring(1);
      parts.add(part);
    }
    var constraintToParse = parts.join(' ');

    try {
      var constraint = PackageManager.parseConstraint(constraintToParse, convertExactToUseful);
      return constraint;
    } catch(e) {
      Log.exception(e, 'Package: $packageName, parsing constraint');
      return null;
    }
  }

  static String normalizeVersion(String versionStr) {
    String versionToParse;
    if(RegExp(r'^v?\d+.\d+$').hasMatch(versionStr))
      versionToParse = '$versionStr.0';
    else
      versionToParse = versionStr;
    if(versionToParse.startsWith('v'))
      versionToParse = versionToParse.substring(1);
    return versionToParse;
  }
}
