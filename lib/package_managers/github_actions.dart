// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

import '../common/package.dart';
import '../common/package_manager.dart';
import '../sites/github.dart';
import '../util/downloader.dart';
import '../util/logger.dart';

class GitHubActionsPackage extends Package {
  GitHubActionsPackage({
    required super.name,
    required super.shortName,
    required super.version,
    required super.constraintStr,
    required super.constraint,
    required super.isDev,
    required super.infoUrl
  });

  @override
  Future<RepoPackage> fetchRepoPackage(String infoUrl) async {
    var repoUrl = GitHub.dropExtraSlugFromUrl(infoUrl);
    var tagsUrl = '$repoUrl/refs?type=tag';
    var info = await Downloader.getJsonObject(tagsUrl);
    List<dynamic> tags;
    try {
      tags = info['refs'] as List<dynamic>;
    } catch(e) {
      logException(e, 'fetching tags tags');
      rethrow;
    }
    var versions = <PackageVersion>[];
    for(var (index, tagItem) in tags.indexed) {
      try {
        var tag = tagItem as String;
        var version = parseVersion(tag);
        versions.add(PackageVersion(version: version, releasedAt: null));
      } catch(e) {
        logException(e, '$infoUrl > tags[$index]');
      }
    }

    var links = <PackageLink>[];
    links.add(PackageLink(
      name: 'Marketplace',
      url: infoUrl,
      isVisibleToUser: true
    ));

    var repoPackage = RepoPackage(
      links: links,
      versions: versions
    );
    return repoPackage;
  }

  static Version parseVersion(String v) {
    if(v.startsWith('v') || v.startsWith('V'))
      v = v.substring(1);
    var version = Version.parse(v);
    return version;
  }
}

class GitHubActions extends PackageManager {
  GitHubActions({
    required super.filename,
    required super.projectName,
    required super.packages
  }): super(name: 'GitHub Actions');

  static Future<GitHubActions?> fromDirOrFile(String filePath) async {
    var fileAndProjectDirName = await yamlFileAndProjectDirNameByDirOrFilename(filePath);
    if(fileAndProjectDirName == null)
      return null;
    var (file, projectDirName) = fileAndProjectDirName;
    var yamlContent = await file.readAsString();
    var root = loadYaml(yamlContent) as YamlMap;
    var jobs = root['jobs'] as YamlMap? ?? YamlMap();
    var packages = <Package>[];
    for(var job in jobs.entries) {
      var jobName = job.key;
      YamlList steps;
      try {
        steps = (job.value as YamlMap)['steps'] as YamlList? ?? YamlList();
      } catch(e) {
        Log.exception(e, '$jobName > steps');
        continue;
      }
      for(var (stepIndex, step) in steps.indexed) {
        var stepName = step['name'] as String?;
        var uses = step['uses'] as String? ?? '';
        if(uses.isEmpty)
          continue;
        var pathInYaml = stepName == null
          ? '$jobName > steps[$stepIndex]'
          : '$jobName > $stepName';
        var m = RegExp(r'^([^/]+/[^@]+)(?:@(.*))?$').firstMatch(uses);
        if(m == null) {
          Log.error('$pathInYaml > uses=$uses: package format is not supported');
          continue;
        }
        var packageName = m.group(1) ?? '';
        var constraintStr = m.group(2) ?? '';
        Version? version;
        VersionConstraint? constraint;
        try {
          version = GitHubActionsPackage.parseVersion(constraintStr);
          constraint = VersionConstraint.compatibleWith(version);
        } catch(e) {
          Log.exception(e, pathInYaml);
        }
        var displayedPackageName = '$pathInYaml > $packageName';
        var package = GitHubActionsPackage(
          name: displayedPackageName,
          shortName: packageName,
          version: version,
          constraintStr: constraintStr,
          constraint: constraint,
          isDev: false,
          infoUrl: '${GitHub.marketplacePrefix}/$packageName'
        );
        packages.add(package);
      }
    }

    String projectName;
    var workflowName = path.basenameWithoutExtension(file.path);
    if(projectDirName.isEmpty)
      projectName = workflowName;
    else
      projectName = '$projectDirName/$workflowName';
    var manager = GitHubActions(
      filename: file.path,
      projectName: projectName,
      packages: packages
    );
    return manager;
  }

  static String? projectDirNameByWorkflowsDirectory(Directory workflowsDir) {
    if(path.basename(workflowsDir.path) == 'workflows') {
      var dotGithubDir = workflowsDir.parent;
      if(path.basename(dotGithubDir.path) == '.github') {
        var projDir = dotGithubDir.parent;
        var projectName = path.basename(projDir.path);
        return projectName;
      }
    }
    return null;
  }

  static Future<(File, String)?> yamlFileAndProjectDirNameByDirOrFilename(String filename) async {
    var file = File(filename);
    if(path.extension(filename).toLowerCase() == '.yaml' && await file.exists()) {
      var projectDirName = projectDirNameByWorkflowsDirectory(file.parent);
      if(projectDirName == null)
        return null;
      return (file, projectDirName);
    }

    var dir = Directory(filename);
    if(!await dir.exists())
      return null;
    var projectDirName = projectDirNameByWorkflowsDirectory(dir);
    if(projectDirName == null) {
      if(path.basename(dir.path) == '.github') {
        dir = Directory('${dir.path}/workflows');
        if(!await dir.exists())
          return null;
        projectDirName = projectDirNameByWorkflowsDirectory(dir);
      } else {
        dir = Directory('${dir.path}/.github/workflows');
        if(!await dir.exists())
          return null;
        projectDirName = projectDirNameByWorkflowsDirectory(dir);
      }
    }
    if(projectDirName == null)
      return null;

    await for(var entry in dir.list()) {
      if(entry is File && path.extension(entry.path).toLowerCase() == '.yaml') {
        return (entry, projectDirName);
      }
    }
    return null;
  }
}
