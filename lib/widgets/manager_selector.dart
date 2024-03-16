// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';

import '../common/package_manager.dart';

class ManagerSelector extends StatelessWidget {
  const ManagerSelector({
    required this.managers,
    required this.onSelected
  });

  final List<PackageManager> managers;
  final Function(PackageManager) onSelected;

  @override
  Widget build(context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: managers.map((m) {
        return Padding(
          padding: const EdgeInsets.all(10),
          child: ElevatedButton(
            child: Text('${m.projectName} [${m.name}]'),
            onPressed: () => onSelected(m),
          )
        );
      }).toList()
    );
  }
}
