// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';

import '../content_source/markdown.dart';
import '../util/logger.dart';

abstract class ContentSource {
  ContentSource({
    required this.url
  });

  final String url;

  final loadingNotification = ValueNotifier(true);
  var rawContent = '';
  var _canLoadMore = true;
  bool get canLoadMore => _canLoadMore;
  var loadedOnce = false;

  Widget get widget {
    if(!loadedOnce) {
      loadedOnce = true;
      loadMore();
    }
    var widget = widgetByRaw(rawContent);
    return widget;
  }

  Future<(String, bool)> fetchNextPage();

  Widget widgetByRaw(String rawContent);

  Future<void> loadMore() async {
    if(!_canLoadMore)
      return;

    loadingNotification.value = true;
    try {
      var (newRawContent, canLoadNext) = await fetchNextPage();
      _canLoadMore = canLoadNext;
      rawContent += newRawContent;
    } catch(e) {
      Log.exception(e, 'loading more from $url');
    }
    loadingNotification.value = false;
  }

  static ContentSource? byFilenameAndUrl(String filename, String url) {
    if(Markdown.isSupportedFilename(filename))
      return Markdown(url: url);
    return null;
  }
}

abstract class Content {
  const Content();

  Widget get widget;
}
