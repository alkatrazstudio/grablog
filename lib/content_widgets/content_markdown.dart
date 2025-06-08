// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';

import 'package:markdown_widget/markdown_widget.dart';

class ContentMarkdown extends StatelessWidget {
  const ContentMarkdown({
    super.key,
    required this.markdown
  });

  final String markdown;

  @override
  Widget build(context) {
    return MarkdownBlock(data: markdown);
  }
}
