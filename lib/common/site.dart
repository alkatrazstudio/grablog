// SPDX-License-Identifier: AGPL-3.0-only

import '../common/changelog.dart';
import '../sites/github.dart';
import '../sites/pub_dev.dart';

abstract class Site {
  Site({
    required this.name,
    required this.author,
    required this.project
  });

  final String name;
  final String author;
  final String project;

  Future<List<Changelog>> fetchChangelogs();
  String get baseUrl;

  static const constructors = [
    GitHub.byUrl,
    PubDev.byUrl
  ];

  static Site? byLinkUrl(String url) {
    for(var constructor in constructors) {
      var site = constructor(url);
      if(site != null)
        return site;
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    if(other is Site)
      return name == other.name && author == other.author && project == other.project;
    return false;
  }

  @override
  // TODO: implement hashCode
  int get hashCode => Object.hash(name, author, project);
}
