// SPDX-License-Identifier: AGPL-3.0-only

import 'content.dart';

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
