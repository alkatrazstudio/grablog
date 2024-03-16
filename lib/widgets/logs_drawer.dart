// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../util/dialogs.dart' as dialogs;
import '../util/logger.dart';
import '../widgets/help_popup.dart';
import '../widgets/pad.dart';

class LogsDrawer extends StatelessWidget {
  const LogsDrawer();

  static String get text => '${Log.notifier.value.join('\n')}\n';

  @override
  Widget build(context) {
    return Drawer(
      width: 720,
      child: Column(
        children: [
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: Log.notifier,
              builder: (context, value, child) {
                return Padding(
                  padding: Pad.horizontal,
                  child: ListView(
                    children: value.map((item) => Text(item)).toList(),
                  )
                );
              }
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () async {
                  if(context.mounted)
                    helpPopup(context);
                },
                child: const Text('Help')
              ),
              ElevatedButton(
                onPressed: () async {
                  Log.notifier.value = [];
                },
                child: const Text('Clear')
              ),
              ElevatedButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: text));
                },
                child: const Text('Copy to clipboard')
              ),
              ElevatedButton(
                onPressed: () async {
                  await dialogs.saveFile(
                    context: context,
                    name: 'logsCsvExport',
                    suggestedNamePrefix: 'grablog_logs',
                    suggestedNameExtension: 'txt',
                    getContent: () async => text
                  );
                },
                child: const Text('Save to file')
              ),
              ElevatedButton(
                onPressed: () {
                  Scaffold.of(context).closeEndDrawer();
                },
                child: const Text('Close')
              )
            ],
          )
        ],
      )
    );
  }
}
