// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';

import 'package:markdown_widget/markdown_widget.dart';
import 'package:url_launcher/url_launcher_string.dart';

class ContentMarkdown extends StatelessWidget {
  const ContentMarkdown({
    super.key,
    required this.baseUrl,
    required this.markdown
  });

  final String markdown;
  final String baseUrl;

  @override
  Widget build(context) {
    return MarkdownBlock(
      data: markdown,
      config: MarkdownConfig(
        configs: [
          LinkConfig(
            style: TextStyle(
              decoration: TextDecoration.none,
              color: Theme.of(context).colorScheme.primaryFixedDim
            ),
            onTap: (url) {
              if(url.isNotEmpty) {
                url = Uri.parse(baseUrl).resolve(url).toString();
                launchUrlString(url);
              }
            },
          ),
          const CodeConfig(
            style: TextStyle()
          )
        ]
      ),
    );
  }
}
