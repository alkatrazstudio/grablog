// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

import '../common/package.dart';
import '../common/package_manager.dart';
import '../util/downloader.dart';
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

  static var yarn2NameRx = RegExp(r'^(@?[^@]+)@npm:(?:(@?[^@]+)@)?(.+)$');

  static Future<Yarn?> fromDirOrFile(String path) async {
    var files = await PackageManager.loadPackagesAndLockFiles(path, 'yarn.lock', 'package.json');
    if(files == null)
      return null;
    var (lockFilename, lockContent, packagesJson) = files;

    var packageJsonMap = jsonDecode(packagesJson) as Map<String, dynamic>;
    var projectName = (packageJsonMap['name'] as String?) ?? '';

    var lockEntries = extractLockEntries(lockContent);
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

  static List<LockEntry> extractLockEntriesFromVersion1(String lockContent) {
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

  static (String, String) splitNameAndVersionSpec(String fullName) {
    // examples:
    // string-env-interpolation@npm:^1.0.1
    // @apollo/client@npm:^3.9.10
    // string-width-cjs@npm:string-width@^4.2.0 - here we take the second name, since the first one is overriden by it
    var match = yarn2NameRx.firstMatch(fullName);
    if(match == null)
      throw Exception('$fullName - cannot parse');
    var name = match.group(2) ?? match.group(1)!;
    var versionSpec = match.group(3)!;
    return (name, versionSpec);
  }

  static List<LockEntry> extractLockEntriesFromVersion2(String lockContent) {
    var lockMap = loadYaml(lockContent) as YamlMap;
    var lockEntries = <LockEntry>[];
    for(var entry in lockMap.entries) {
      var key = entry.key as String;
      if(key == '__metadata')
        continue;
      if(key.contains('#optional'))
        continue;
      if(key.contains('workspace:'))
        continue;
      var fullNames = key.split(',').map((s) => s.trim()).toList();
      var props = entry.value as YamlMap;
      Version? version;
      String? infoUrl;
      if(props.containsKey('version')) {
        try {
          var versionStr = props['version'] as String;
          version = Version.parse(versionStr);
        } catch(e) {
          Log.exception(e, 'Package "$key", parsing version');
        }
      }
      if(props.containsKey('resolution')) {
        try {
          var resolutionStr = props['resolution'] as String;
          var (name, _) = splitNameAndVersionSpec(resolutionStr);
          infoUrl = 'https://registry.yarnpkg.com/$name'; // Yarn 2+ doesn't provide the actual URL
        } catch(e) {
          Log.exception(e, 'Package "$key", parsing resolution');
        }
      }

      for(var fullName in fullNames) {
        String name;
        String versionSpec;
        try {
          (name, versionSpec) = splitNameAndVersionSpec(fullName);
        } catch(e) {
          Log.exception(e, 'Package "$key", parsing name');
          continue;
        }

        var entry = LockEntry(
          name: name,
          versionSpec: versionSpec,
          meta: LockEntryMeta(
            version: version,
            infoUrl: infoUrl
          ),
          isDev: false
        );
        lockEntries.add(entry);
      }
    }
    return lockEntries;
  }

  static List<LockEntry> extractLockEntries(String lockContent) {
    var isVersion2 = RegExp(r'^__metadata:$', multiLine: true).hasMatch(lockContent);
    var entries = isVersion2
      ? extractLockEntriesFromVersion2(lockContent)
      : extractLockEntriesFromVersion1(lockContent);
    return entries;
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
