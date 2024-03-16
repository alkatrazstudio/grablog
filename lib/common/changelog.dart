// SPDX-License-Identifier: AGPL-3.0-only

import 'package:pub_semver/pub_semver.dart';

import 'content.dart';

class ChangelogEntry {
  const ChangelogEntry({
    required this.version,
    required this.content
  });

  final Version version;
  final Content content;
}

class Changelog {
  const Changelog({
    required this.name,
    required this.url,
    required this.contentSource
  });

  final String name;
  final String url;
  final ContentSource contentSource;
}
