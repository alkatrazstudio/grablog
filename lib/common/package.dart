// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:pub_semver/pub_semver.dart';

import '../common/changelog.dart';
import '../common/site.dart';
import '../util/logger.dart';

abstract class Package {
  Package({
    required this.name,
    required this.version,
    required this.constraintStr,
    required this.constraint,
    required this.isDev,
    required String? infoUrl
  }): _infoUrl = infoUrl;

  final String name;
  final Version? version;
  final String constraintStr;
  final VersionConstraint? constraint;
  final bool isDev;
  final String? _infoUrl;

  Future<RepoPackage>? _repoPackage;
  Future<RepoPackage> get repoPackage {
    try {
      if(_infoUrl == null)
        throw Exception('No info url');
      _repoPackage ??= fetchRepoPackage(_infoUrl);
    } catch(e) {
      _repoPackage = Future.value(RepoPackage(links: [], versions: []));
      logException(e, 'fetching repo package');
    }
    return _repoPackage!;
  }
  Future<RepoPackage> fetchRepoPackage(String infoUrl);

  void logException(Object e, String extraContext) {
    Log.exception(e, 'Package $name${isDev ? ' (dev)' : ''}, $extraContext (${_infoUrl ?? 'no URL'})');
  }
}

class PackageVersion implements Comparable<PackageVersion> {
  PackageVersion({
    required this.version,
    required this.releasedAt
  });

  final Version version;
  final DateTime? releasedAt;

  @override
  int compareTo(PackageVersion other) {
    return version.compareTo(other.version);
  }
}

class ChangelogsNotifier extends ValueNotifier<List<Changelog>?> {
  ChangelogsNotifier(super.value);
}

class PackageLink {
  const PackageLink({
    required this.name,
    required this.url,
    required this.isVisibleToUser
  });

  final String name;
  final String url;
  final bool isVisibleToUser;
}

class RepoPackage {
  RepoPackage({
    required List<PackageLink> links,
    required List<PackageVersion> versions
  }) {
    this.links.addAll(links);
    for(var link in this.links) {
      var site = Site.byLinkUrl(link.url);
      if(site != null && !sites.contains(site))
        sites.add(site);
    }
    for(var site in sites) {
      this.links.add(PackageLink(name: site.name, url: site.baseUrl, isVisibleToUser: true));
    }

    this.versions.addAll(versions);
    this.versions.sort();
  }

  ChangelogsNotifier? _changelogs;
  ChangelogsNotifier get changelogs {
    var result = _changelogs;
    if(result != null)
      return result;
    result = ChangelogsNotifier(null);
    _changelogs = result;
    fillChangelogs(result);
    return result;
  }

  final sites = <Site>[];
  final links = <PackageLink>[];
  final versions = <PackageVersion>[];

  PackageVersion? get latestRelease => versions.lastWhereOrNull((v) => !v.version.isPreRelease);

  PackageVersion? getLatestReleaseForConstraint(VersionConstraint constraint) {
    var pkgVer = versions.lastWhereOrNull((v) => !v.version.isPreRelease && constraint.allows(v.version));
    return pkgVer;
  }

  Future<void> fillChangelogs(ChangelogsNotifier changelogsNotifier) async {
    for(var site in sites) {
      try {
        var newChangelogs = await site.fetchChangelogs();
        changelogsNotifier.value = (changelogs.value ?? []) + newChangelogs;
      } catch(e) {
        Log.exception(e, 'fetching changelog from ${site.baseUrl}');
      }
    }
    changelogs.value ??= [];
  }
}
