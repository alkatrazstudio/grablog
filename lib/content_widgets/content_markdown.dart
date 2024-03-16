// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';

import 'package:flutter_markdown/flutter_markdown.dart';

class ContentMarkdown extends StatelessWidget {
  const ContentMarkdown({
    super.key,
    required this.markdown
  });

  final String markdown;

  @override
  Widget build(context) {
    return MarkdownBody(data: markdown);
  }
}
