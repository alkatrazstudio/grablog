// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../widgets/app.dart';

Future<void> helpPopup(BuildContext context) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        content: FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            var packageInfo = snapshot.data;
            if(packageInfo == null)
              return const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator()
                ]
              );

            var appVersionLine = App.extractVersionLine(packageInfo);
            var repoUrl = 'https://github.com/alkatrazstudio/grablog';
            var appGitHash = App.gitHash;
            var licenseUrl = '$repoUrl/blob/${appGitHash.isNotEmpty ? appGitHash : 'master'}/LICENSE.md';

            return RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$appVersionLine\n\n',
                    style: TextStyle(fontSize: Theme.of(context).textTheme.headlineSmall?.fontSize)
                  ),
                  TextSpan(
                    text: repoUrl,
                    style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => launchUrlString(repoUrl),
                  ),
                  if(appGitHash.isNotEmpty)
                    const TextSpan(
                      text: '\n\nGit hash: '
                    ),
                  if(appGitHash.isNotEmpty)
                    TextSpan(
                      text: appGitHash,
                      style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => launchUrlString('$repoUrl/tree/$appGitHash'),
                    ),
                  const TextSpan(
                    text: '\n\nLicense: '
                  ),
                  TextSpan(
                    text: 'AGPLv3',
                    style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => launchUrlString(licenseUrl),
                  )
                ]
              ),
            );
          },
        ),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}
