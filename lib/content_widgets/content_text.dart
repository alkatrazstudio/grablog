// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';

class ContentText extends StatelessWidget {
  const ContentText({
    super.key,
    required this.baseUrl,
    required this.text
  });

  final String text;
  final String baseUrl;

  @override
  Widget build(context) {
    return SelectableText(text);
  }
}
