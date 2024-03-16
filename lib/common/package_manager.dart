// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';

import '../common/package.dart';
import '../package_managers/cargo.dart';
import '../package_managers/composer.dart';
import '../package_managers/pub.dart';
import '../package_managers/yarn.dart';
import '../util/logger.dart';

class PackageEntry {
  const PackageEntry({
    required this.name,
    required this.constraintStr,
    this.constraint,
    required this.isDev
  });

  final String name;
  final String constraintStr;
  final VersionConstraint? constraint;
  final bool isDev;
}

class LockEntryMeta {
  Version? version;
  String? infoUrl;

  LockEntryMeta({
    this.version,
    this.infoUrl
  });
}

class LockEntry {
  const LockEntry({
    required this.name,
    required this.versionSpec,
    required this.meta,
    required this.isDev
  });

  final String name;
  final String versionSpec;
  final LockEntryMeta meta;
  final bool isDev;
}


abstract class PackageManager {
  PackageManager({
    required this.filename,
    required this.name,
    required this.projectName,
    required packages,
  }) {
    this.packages.addAll(packages);
    this.packages.sort((p1, p2) {
      if(p1.isDev != p2.isDev)
        return p1.isDev ? 1 : -1;
      return p1.name.compareTo(p2.name);
    });
  }

  final String filename;
  final String name;
  final String projectName;
  final packages = <Package>[];

  static Future<File?> getFile(String fullPath, String basename) async {
    File file;
    if(path.basename(fullPath) == basename) {
      file = File(fullPath);
      if(await file.exists())
        return file;
    }
    var dir = Directory(fullPath);
    if(!await dir.exists())
      return null;
    file = File('${dir.path}/$basename');
    return file;
  }

  static Future<(String packageFileContent, String lockFileContent, String lockFileName)?> loadPackagesAndLockFiles(
    String lockFilePath,
    String lockFileName,
    String packagesFileName
  ) async {
    var lockFile = await PackageManager.getFile(lockFilePath, lockFileName);
    if(lockFile == null)
      return null;
    var dir = lockFile.parent.path;
    var packagesFile = File('$dir/$packagesFileName');
    if(!await packagesFile.exists())
      return null;
    var lockFileContent = await lockFile.readAsString();
    var packageFileContent = await packagesFile.readAsString();
    return (lockFile.path, lockFileContent, packageFileContent);
  }

  static const constructors = [
    Yarn.fromDirOrFile,
    Composer.fromDirOrFile,
    Pub.fromDirOrFile,
    Cargo.fromDirOrFile
  ];

  static Future<List<PackageManager>> fromDirOrFile(String fullPath) async {
    fullPath = path.normalize(fullPath);
    var managers = <PackageManager>[];
    for(var constructor in constructors) {
      try {
        var manager = await constructor(fullPath);
        if(manager != null)
          managers.add(manager);
      } catch(e) {
        Log.exception(e, 'constructing manager');
      }
    }
    return managers;
  }

  Future<PackageManager> loadNew() async {
    var managers = await fromDirOrFile(filename);
    if(managers.length != 1)
      throw Exception('More than one manager found by filename: $filename');
    return managers.first;
  }
}
