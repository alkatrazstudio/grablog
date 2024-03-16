// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:pub_semver/pub_semver.dart';

import '../common/downloader.dart';
import '../common/package.dart';
import '../common/package_manager.dart';
import '../util/logger.dart';

class YarnPackage extends Package {
  YarnPackage({
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
    var timeMap = info['time'] as Map<String, dynamic>;
    var versions = <PackageVersion>[];
    for(var entry in timeMap.entries) {
      if(entry.key == 'created' || entry.key == 'modified')
        continue;
      Version version;
      try {
        version = Version.parse(entry.key);
      } catch(e) {
        logException(e, '$infoUrl > time');
        continue;
      }
      var releasedAt = DateTime.tryParse(entry.value);
      if(releasedAt == null)
        continue;
      versions.add(PackageVersion(version: version, releasedAt: releasedAt));
    }

    var links = <PackageLink>[];
    var homepage = info['homepage'];
    if(homepage is String)
      links.add(PackageLink(name: 'Homepage', url: homepage, isVisibleToUser: true));
    var repoObj = info['repository'];
    if(repoObj is Map<String, dynamic>) {
      var repoUrl = repoObj['url'];
      if(repoUrl is String)
        links.add(PackageLink(name: 'Repository', url: repoUrl, isVisibleToUser: false));
    }
    var bugsObj = info['bugs'];
    if(bugsObj is Map<String, dynamic>) {
      var bugsUrl = bugsObj['url'];
      if(bugsUrl is String)
        links.add(PackageLink(name: 'Bugs', url: bugsUrl, isVisibleToUser: true));
    }

    links.add(PackageLink(name: 'NPM', url: 'https://www.npmjs.com/package/$name', isVisibleToUser: true));

    return RepoPackage(
      links: links,
      versions: versions
    );
  }
}

class Yarn extends PackageManager {
  Yarn({
    required super.filename,
    required super.projectName,
    required super.packages
  }): super(name: 'Yarn');

  static Future<Yarn?> fromDirOrFile(String path) async {
    var files = await PackageManager.loadPackagesAndLockFiles(path, 'yarn.lock', 'package.json');
    if(files == null)
      return null;
    var (lockFilename, lockContent, packagesJson) = files;

    var packageJsonMap = jsonDecode(packagesJson) as Map<String, dynamic>;
    var projectName = (packageJsonMap['name'] as String?) ?? '';

    var lockEntries = await extractLockEntries(lockContent);
    var entriesDist = extractEntries(packageJsonMap, false);
    var entriesDev = extractEntries(packageJsonMap, true);
    var packageEntries = entriesDist + entriesDev;

    var packages = packageEntries.map((packageEntry) {
      var lockEntry = lockEntries.firstWhereOrNull(
        (lockEntry) => lockEntry.name == packageEntry.name && lockEntry.versionSpec == packageEntry.constraintStr);
      var package = YarnPackage(
        name: packageEntry.name,
        version: lockEntry?.meta.version,
        constraintStr: packageEntry.constraintStr,
        constraint: packageEntry.constraint,
        isDev: packageEntry.isDev,
        infoUrl: lockEntry?.meta.infoUrl
      );
      return package;
    }).toList();

    return Yarn(
      filename: lockFilename,
      projectName: projectName,
      packages: packages
    );
  }

  static Future<List<LockEntry>> extractLockEntries(String lockContent) async {
    var lockLines = lockContent.split(RegExp(r'[\n\r]+'));
    lockLines.add('');
    var lockEntries = <LockEntry>[];
    List<String>? curSpecs;
    LockEntryMeta? curMeta;
    var resolvedRx = RegExp(r'^https?://.*(?=/-/)');
    for (var lockLine in lockLines) {
      if(!lockLine.startsWith(' ')) {
        if(curSpecs != null && curMeta != null) {
          for(var spec in curSpecs) {
            var parts = spec.split('@');
            if(parts.length <= 1)
              continue;
            var versionSpec = parts.removeLast();
            var name = parts.join('@');
            var lockEntry = LockEntry(
              name: name,
              versionSpec: versionSpec,
              meta: curMeta,
              isDev: false
            );
            lockEntries.add(lockEntry);
          }

          curSpecs = null;
          curMeta = null;
        }

        if(!lockLine.startsWith('#') && lockLine.endsWith(':')) {
          lockLine = lockLine.substring(0, lockLine.length - 1);
          curSpecs = lockLine.split(',').map((spec) {
            spec = spec.trim();
            if(spec.startsWith('"') && spec.endsWith('"'))
              spec = jsonDecode(spec) as String;
            return spec;
          }).toList();
        }
      } else {
        var keyVal = lockLine.trim().split(' ');
        var key = keyVal.removeAt(0);
        if(keyVal.isEmpty)
          continue;
        var val = keyVal.join(' ');
        if(val.startsWith('"') && val.endsWith('"'))
          val = jsonDecode(val) as String;
        switch(key) {
          case 'version':
            curMeta ??= LockEntryMeta();
            try {
              curMeta.version = Version.parse(val);
            } catch(e) {
              Log.exception(e, 'Package ${curSpecs?.join(',')}, parsing version');
            }
            break;

          case 'resolved':
            curMeta ??= LockEntryMeta();
            var infoUrl = resolvedRx.stringMatch(val);
            curMeta.infoUrl = infoUrl;
            break;
        }
      }
    }
    return lockEntries;
  }

  static List<PackageEntry> extractEntries(Map<String, dynamic> packageJsonMap, bool isDev) {
    var mapKey = isDev ? 'devDependencies' : 'dependencies';
    var dependenciesMap = (packageJsonMap[mapKey] as Map<String, dynamic>?) ?? {};
    var packageEntries = dependenciesMap.entries.map((entry) {
      VersionConstraint? constraint;
      var constraintStr = entry.value as String;
      try {
        var compatConstraintStr = constraintStr.startsWith('=') ? constraintStr.substring(1) : constraintStr;
        constraint = VersionConstraint.parse(compatConstraintStr);
      } catch(e) {
        Log.exception(e, 'Package: ${entry.key}');
      }

      var packageEntry = PackageEntry(
        name: entry.key,
        constraintStr: constraintStr,
        constraint: constraint,
        isDev: isDev
      );
      return packageEntry;
    }).toList();
    return packageEntries;
  }
}
