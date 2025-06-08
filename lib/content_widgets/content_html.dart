// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';

import 'package:flutter_html/flutter_html.dart';

class ContentHtml extends StatelessWidget {
  const ContentHtml({
    super.key,
    required this.html
  });

  final String html;

  @override
  Widget build(context) {
    return SelectionArea(
      child: Html(
        data: html,
        style: {
          'a': Style(
            textDecoration: TextDecoration.none
          )
        },
        extensions: [
          ImageExtension(handleNetworkImages: false)
        ],
      )
    );
  }
}
