// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';

import '../common/content.dart';
import '../content_widgets/content_html.dart';
import '../util/downloader.dart';

class GitHubReleasesContentSource extends ContentSource {
  GitHubReleasesContentSource({
    required super.url
  });

  var curPage = 1;

  @override
  Future<(String, bool)> fetchNextPage() async {
    var doc = await Downloader.getHtml('$url?page=$curPage');
    var els = doc.querySelectorAll('.Box-body');
    if(els.isEmpty) {
      if(curPage == 1)
        return ('<p>No releases found</p>', false);
      return ('', false);
    }
    var html = els.map((el) => el.innerHtml).join('<hr>');
    html += '<hr>';
    curPage += 1;
    return (html, true);
  }

  @override
  Widget widgetByRaw(String rawContent) {
    return ContentHtml(
      key: ValueKey(this),
      baseUrl: url,
      html: rawContent
    );
  }
}
