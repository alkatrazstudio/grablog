// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/package_manager.dart';
import '../common/state.dart';
import '../widgets/changelogs_pane.dart';
import '../widgets/packages_pane.dart';
import '../widgets/pad.dart';

class CentralPane extends StatelessWidget {
  const CentralPane({
    required this.manager
  });

  final PackageManager manager;

  @override
  Widget build(context) {
    return Row(
      key: ValueKey(manager),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: Pad.top,
            child: PackagesPane(
              manager: manager
            )
          )
        ),
        Expanded(
          child: Consumer(
            builder: (context, ref, child) {
              var selected = ref.watch(selectedProvider);
              if(selected.packageIndex < 0)
                return const Text('Select a package', textAlign: TextAlign.center);
              var package = manager.packages[selected.packageIndex];
              return ChangelogsPane(package: package);
            },
          )
        )
      ]
    );
  }
}
