// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';

import 'package:path/path.dart' as path;

import '../common/content.dart';
import '../common/downloader.dart';
import '../content_widgets/content_markdown.dart';

class Markdown extends ContentSource {
  Markdown({
    required super.url
  });

  static const supportedExt = '.MD';

  static bool isSupportedFilename(String filename) {
    var ext = path.extension(filename);
    if(ext.toUpperCase() == supportedExt)
      return true;
    return false;
  }

  @override
  Future<(String, bool)> fetchNextPage() async {
    var newContent = await Downloader.get(url);
    return (newContent, false);
  }

  @override
  Widget widgetByRaw(String rawContent) {
    return ContentMarkdown(
      key: ValueKey(this),
      markdown: rawContent
    );
  }
}
