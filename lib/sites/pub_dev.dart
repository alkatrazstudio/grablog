// SPDX-License-Identifier: AGPL-3.0-only

import '../common/changelog.dart';
import '../common/site.dart';
import '../content_source/pub_dev_releases.dart';

class PubDev extends Site {
  PubDev({
    required super.project
  }): super(author: '', name: 'Pub');

  static PubDev? byUrl(String url) {
    var m = RegExp(r'^https://pub\.dev/packages/([^/]+)$').firstMatch(url);
    if(m == null)
      return null;
    return PubDev(
      project: m.group(1)!
    );
  }

  @override
  String get baseUrl => 'https://pub.dev/packages/$project';

  @override
  Future<List<Changelog>> fetchChangelogs() async {
    var changelogUrl = '$baseUrl/changelog';
    return [
      Changelog(
        name: name,
        url: changelogUrl,
        contentSource: PubDevReleasesContentSource(
          url: changelogUrl
        )
      )
    ];
  }
}
