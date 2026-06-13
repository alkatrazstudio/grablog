// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';

import 'package:path/path.dart' as path;

import '../common/content.dart';
import '../content_widgets/content_text.dart';
import '../util/downloader.dart';

class PlainText extends ContentSource {
  PlainText({
    required super.url
  });

  static const supportedExt = '.TXT';

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
    return ContentText(
      key: ValueKey(this),
      baseUrl: url,
      text: rawContent
    );
  }
}
