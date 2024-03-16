// SPDX-License-Identifier: AGPL-3.0-only

import 'package:collection/collection.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:toml/toml.dart';

import '../common/downloader.dart';
import '../common/package.dart';
import '../common/package_manager.dart';
import '../util/logger.dart';

class CargoPackage extends Package {
  CargoPackage({
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
    var versions = info['versions'] as List<dynamic>;
    var versionObjs = <PackageVersion>[];
    for(var (index, versionItem) in versions.indexed) {
      try {
        var versionMap = versionItem as Map<String, dynamic>;
        var versionStr = versionMap['num'] as String;
        var version = Version.parse(versionStr);
        var timeStr = versionMap['updated_at'] as String?;
        var releasedAt = timeStr == null ? null : DateTime.tryParse(timeStr);
        var versionObj = PackageVersion(
          version: version,
          releasedAt: releasedAt
        );
        versionObjs.add(versionObj);
      } catch(e) {
        logException(e, '$infoUrl > version index $index');
      }
    }

    var links = <PackageLink>[];
    links.add(PackageLink(
        name: 'Crates',
        url: 'https://crates.io/crates/$name',
        isVisibleToUser: true
    ));
    links.add(PackageLink(
      name: 'Docs',
      url: 'https://docs.rs/$name',
      isVisibleToUser: true
    ));

    try {
      var crateInfo = info['crate'] as Map<String, dynamic>;
      try {
        var homepage = crateInfo['homepage'] as String;
        links.add(PackageLink(
          name: 'Homepage',
          url: homepage,
          isVisibleToUser: true
        ));
      } catch(e) {
        logException(e, 'fetching create.homepage');
      }
      try {
        var repository = crateInfo['repository'] as String;
        links.add(PackageLink(
          name: 'Repository',
          url: repository,
          isVisibleToUser: true
        ));
      } catch(e) {
        Log.exception(e, 'fetching crate.repository');
      }
    } catch(e) {
      Log.exception(e, 'fetching crate info');
    }

    var repoPackage = RepoPackage(
      links: links,
      versions: versionObjs
    );
    return repoPackage;
  }
}


class Cargo extends PackageManager {
  Cargo({
    required super.filename,
    required super.projectName,
    required super.packages
  }): super(name: 'Cargo');

  static Future<Cargo?> fromDirOrFile(String path) async {
    var files = await PackageManager.loadPackagesAndLockFiles(path, 'Cargo.lock', 'Cargo.toml');
    if(files == null)
      return null;
    var (lockFilename, lockToml, packagesToml) = files;

    var lockMap = TomlDocument.parse(lockToml).toMap();
    var lockEntries = extractLockEntries(lockMap);
    var packagesMap = TomlDocument.parse(packagesToml).toMap();
    var projectName = (packagesMap['package']?['name'] as String?) ?? '';
    var packagesDist = extractPackageEntries(packagesMap, false);
    var packagesDev = extractPackageEntries(packagesMap, true);
    var packageEntries = packagesDist + packagesDev;

    var packages = packageEntries.map((packageEntry) {
      var entries = lockEntries.where((lockEntry) => lockEntry.name == packageEntry.name);
      var lockEntry = entries.sortedByCompare((e) => e.meta.version, (v1, v2) {
        if(v2 == null)
          return -1;
        if(v1 == null)
          return 1;
        var constraint = packageEntry.constraint;
        if(constraint != null) {
          if(constraint.allows(v1))
            return -1;
          if(constraint.allows(v2))
            return 1;
        }
        return v1 < v2 ? -1 : 1;
      }).firstOrNull;

      var package = CargoPackage(
        name: packageEntry.name,
        version: lockEntry?.meta.version,
        constraintStr: packageEntry.constraintStr,
        constraint: packageEntry.constraint,
        isDev: packageEntry.isDev,
        infoUrl: lockEntry?.meta.infoUrl
      );
      return package;
    }).toList();

    var manager = Cargo(
        filename: lockFilename,
        projectName: projectName,
        packages: packages
    );
    return manager;
  }

  static List<LockEntry> extractLockEntries(Map<String, dynamic> lockMap) {
    var entries = <LockEntry>[];
    var packageItems = (lockMap['package'] as List<dynamic>?) ?? [];
    for(var packageItem in packageItems) {
      var packageMap = packageItem as Map<String, dynamic>;
      var name = packageMap['name'] as String?;
      if(name == null)
        continue;

      Version? version;
      try {
        version = Version.parse(packageMap['version'] as String);
      } catch(e) {
        Log.exception(e, 'Package $name, lock file, parsing version');
      }
      var lockMeta = LockEntryMeta(
        version: version,
        infoUrl: 'https://crates.io/api/v1/crates/$name'
      );
      var entry = LockEntry(
        name: name,
        versionSpec: '',
        meta: lockMeta,
        isDev: false // no distinction for Cargo lock items
      );
      entries.add(entry);
    }
    return entries;
  }

  static List<PackageEntry> extractPackageEntries(Map<String, dynamic> packagesMap, bool isDev) {
    var entries = <PackageEntry>[];
    var packagesKey = isDev ? 'build-dependencies' : 'dependencies';
    var packagesItems = packagesMap[packagesKey] as Map<String, dynamic>?;
    if(packagesItems == null)
      return [];
    for(var packageItem in packagesItems.entries) {
      var packageName = packageItem.key;

      String? constraintStr;
      try {
        constraintStr = (packageItem.value as String?) ?? '';
      } catch(e) {
        try {
          constraintStr = (packageItem.value['version'] as String?) ?? '';
        } catch(e) {
          constraintStr ??= '';
          Log.exception(e, 'Package $packageName, parsing version');
        }
      }
      var constraint = parseConstraint(constraintStr, packageName);
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

  static VersionConstraint? parseConstraint(String constraintStr, String packageName) {
    var parts = constraintStr.split(',').map((part) => part.trim());
    var constraintParts = <String>[];
    for(var (index, part) in parts.indexed) {
      try {
        part = normalizeConstraintStr(part);
        var constraintPart = VersionConstraint.parse(part).toString();
        constraintParts.add(constraintPart);
      } catch(e) {
        Log.exception(e, 'Package $packageName, parsing constraint part ${index + 1}');
      }
    }
    try {
      var fullConstraintStr = constraintParts.join(' ');
      var constraint = VersionConstraint.parse(fullConstraintStr);
      return constraint;
    } catch(e) {
      Log.exception(e, 'Package $packageName, parsing constraint');
      return null;
    }
  }

  static String normalizeConstraintStr(String constraintStr) {
    constraintStr = constraintStr.replaceAll(' ', '');
    if(constraintStr == '*')
      return 'any';

    if(RegExp(r'^[\^<=>~]*\d+\.\d+$').hasMatch(constraintStr))
      constraintStr = '$constraintStr.0';
    else if(RegExp(r'^[\^<=>~]*\d+$').hasMatch(constraintStr))
      constraintStr = '$constraintStr.0.0';

    if(constraintStr.startsWith(RegExp(r'\d'))) {
      var m = RegExp(r'^(\d+)\.\*(\.|$)').firstMatch(constraintStr);
      if(m != null) {
        var vMajor = int.parse(m.group(1)!);
        constraintStr = '>=$vMajor.0.0 <${vMajor+1}.0.0';
        return constraintStr;
      }
      m = RegExp(r'^(\d+)\.(\d+)\.\*$').firstMatch(constraintStr);
      if(m != null) {
        var vMajor = int.parse(m.group(1)!);
        var vMinor = int.parse(m.group(2)!);
        constraintStr = '>=$vMajor.$vMinor.0 <$vMajor.${vMinor+1}.0';
        return constraintStr;
      }
      return '^$constraintStr';
    }

    if(constraintStr.startsWith('='))
      return constraintStr.substring(1);

    if(constraintStr.startsWith('~')) {
      var m = RegExp(r'^~(\d+)$').firstMatch(constraintStr);
      if(m != null) {
        var vMajor = int.parse(m.group(1)!);
        constraintStr = '>=$vMajor.0.0 <${vMajor+1}.0.0';
        return constraintStr;
      }
      m = RegExp(r'^~(\d+)\.(\d+)(\.\d+)?$').firstMatch(constraintStr);
      if(m != null) {
        var vMajor = int.parse(m.group(1)!);
        var vMinor = int.parse(m.group(2)!);
        constraintStr = '>=$vMajor.$vMinor.0 <$vMajor.${vMinor+1}.0';
        return constraintStr;
      }
    }

    return constraintStr;
  }
}
