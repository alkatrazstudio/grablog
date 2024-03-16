// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';

import '../common/content.dart';
import '../common/downloader.dart';
import '../content_widgets/content_html.dart';

class PubDevReleasesContentSource extends ContentSource {
  PubDevReleasesContentSource({
    required super.url
  });

  @override
  Future<(String, bool)> fetchNextPage() async {
    var doc = await Downloader.getHtml(url);
    var els = doc.querySelectorAll('.changelog-entry');
    if(els.isEmpty)
      return ('<p>No releases found</p>', false);
    var html = els.map((el) => el.innerHtml).join('<hr>');
    html += '<hr>';
    return (html, false);
  }

  @override
  Widget widgetByRaw(String rawContent) {
    return ContentHtml(
      key: ValueKey(this),
      html: rawContent
    );
  }
}
