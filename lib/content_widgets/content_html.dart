// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';

import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher_string.dart';

class ContentHtml extends StatelessWidget {
  const ContentHtml({
    super.key,
    required this.baseUrl,
    required this.html
  });

  final String baseUrl;
  final String html;

  @override
  Widget build(context) {
    return SelectionArea(
      child: Html(
        data: html,
        style: {
          'a': Style(
            textDecoration: TextDecoration.none,
            color: Theme.of(context).colorScheme.primaryFixedDim
          ),
          'hr': Style(
            margin: Margins(top: Margin.zero(), bottom: Margin(20, Unit.px)),
            border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1))
          )
        },
        extensions: [
          ImageExtension(handleNetworkImages: false)
        ],
        onLinkTap: (url, attributes, element) {
          if(url != null && url.isNotEmpty) {
            url = Uri.parse(baseUrl).resolve(url).toString();
            launchUrlString(url);
          }
        },
      )
    );
  }
}
