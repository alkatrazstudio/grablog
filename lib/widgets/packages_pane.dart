// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:csv/csv.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../common/package.dart';
import '../common/package_manager.dart';
import '../common/state.dart';
import '../util/dialogs.dart' as dialogs;
import '../util/prefs.dart';
import '../widgets/pad.dart';
import '../widgets/search_field.dart';

enum PackagesDisplayMode {
  all,
  upgradeable,
  outdated
}

class PackagesPane extends StatefulWidget {
  const PackagesPane({
    super.key,
    required this.manager
  });

  final PackageManager manager;

  @override
  State<PackagesPane> createState() => PackagesPaneState();
}

class TableRowData {
  const TableRowData({
    required this.package,
    required this.index,
    required this.updatedVer,
    required this.repoPackage
  });

  final Package package;
  final int index;
  final PackageVersion? updatedVer;
  final RepoPackage? repoPackage;
}

class PackagesPaneState extends State<PackagesPane> {
  static const modePrefsKey = 'packagesDisplayMode';

  var displayMode = PackagesDisplayMode.upgradeable;
  var search = '';
  var repoPackages = <int, RepoPackage>{};

  Future<void> saveCsv() async {
    await dialogs.saveFile(
      context: context,
      name: 'packagesCsvExport',
      suggestedNamePrefix: '${widget.manager.projectName}_${widget.manager.name}',
      suggestedNameExtension: 'csv',
      getContent: () async {
        var rowsData = currentRowsData();
        var csvRows = <List<String>>[];
        csvRows.add(['Name', 'Dev', 'Constraint', 'Version', 'Updated', 'Latest']);
        csvRows.addAll(rowsData.map((rowData) => [
          rowData.package.name,
          rowData.package.isDev ? 'dev' : '',
          rowData.package.constraintStr,
          rowData.package.version?.toString() ?? '',
          rowData.updatedVer?.version.toString() ?? '',
          rowData.repoPackage?.latestRelease?.version.toString() ?? ''
        ]));
        var csv = const ListToCsvConverter().convert(csvRows);
        return csv;
      }
    );
  }

  bool needToShow(Package package, int index, PackagesDisplayMode mode) {
    var storedRepoPackage = repoPackages[index];
    if(storedRepoPackage == null)
      return true;
    var packageVersion = package.version;

    switch(mode) {
      case PackagesDisplayMode.all:
        return true;

      case PackagesDisplayMode.upgradeable:
        if(packageVersion == null)
          return false;
        var constraint = package.constraint;
        if(constraint == null)
          return false;
        var latestRelease = storedRepoPackage.getLatestReleaseForConstraint(constraint);
        if(latestRelease == null)
          return false;
        return packageVersion < latestRelease.version;

      case PackagesDisplayMode.outdated:
        if(packageVersion == null)
          return false;
        var latestRelease = storedRepoPackage.latestRelease;
        if(latestRelease == null)
          return false;
        return packageVersion < latestRelease.version;
    }
  }

  List<TableRowData> currentRowsData() {
    var rowsData = <TableRowData>[];
    widget.manager.packages.forEachIndexed((index, package) {
      if(search.isNotEmpty && !package.name.toLowerCase().contains(search))
        return;

      var storedRepoPackage = repoPackages[index];
      var show = needToShow(package, index, displayMode);
      if(!show)
        return;

      var constraint = package.constraint;
      var updatedVer = constraint != null
        ? storedRepoPackage?.getLatestReleaseForConstraint(constraint)
        : null;

      rowsData.add(TableRowData(
        package: package,
        index: index,
        updatedVer: updatedVer,
        repoPackage: storedRepoPackage
      ));
    });
    return rowsData;
  }

  @override
  void initState() {
    super.initState();
    var modeName = Prefs.instance.getString(modePrefsKey);
    if(modeName == null)
      return;
    var mode = PackagesDisplayMode.values.firstWhereOrNull((val) => val.name == modeName);
    if(mode != null) {
      displayMode = mode;
    }
  }

  @override
  Widget build(context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            SegmentedButton(
              segments: [
                buttonSegment(PackagesDisplayMode.all),
                buttonSegment(PackagesDisplayMode.upgradeable),
                buttonSegment(PackagesDisplayMode.outdated)
              ],
              selected: {displayMode},
              showSelectedIcon: false,
              onSelectionChanged: (sel) {
                Prefs.instance.setString(modePrefsKey, sel.first.name);
                setState(() {
                  displayMode = sel.first;
                });
              },
            ),
            IconButton(
              onPressed: () {
                saveCsv();
              },
              icon: const Icon(Icons.save)
            )
          ],
        ),
        SearchField(
          onChanged: (text) => setState(() => search = text)
        ),
        Expanded(
          child: Consumer(
            builder: (context, ref, child) {
              var packageIndex = ref.watch(selectedProvider).packageIndex;
              var rowsData = currentRowsData();
              var rows = rowsData.map((rowData) => buildDataRow(rowData, packageIndex == rowData.index, ref)).toList();

              return DataTable2(
                columnSpacing: Pad.pad,
                horizontalMargin: Pad.pad,
                bottomMargin: 0,
                headingRowDecoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                ),
                columns: const [
                  DataColumn2(label: Text('Name')),
                  DataColumn2(label: Align(child: Text('Version')), fixedWidth: 120),
                  DataColumn2(label: Align(child: Text('Updated')), fixedWidth: 70),
                  DataColumn2(label: Align(child: Text('Latest')), fixedWidth: 70)
                ],
                border: TableBorder.all(width: 0, color: Theme.of(context).hintColor),
                dividerThickness: 0,
                rows: rows
              );
            }
          )
        )
      ]
    );
  }

  ButtonSegment<PackagesDisplayMode> buttonSegment(PackagesDisplayMode mode) {
    var packagesCount = widget.manager.packages.whereIndexed((index, package) => needToShow(package, index, mode)).length;
    var label = '${toBeginningOfSentenceCase(mode.name)} ($packagesCount)';
    return ButtonSegment(label: Text(label), value: mode);
  }

  DataRow2 buildDataRow(TableRowData rowData, bool isSelected, WidgetRef ref) {
    return DataRow2(
      key: ValueKey(rowData.package),
      cells: [
        DataCell(
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  rowData.package.name,
                  softWrap: true
                )
              ),
              if(rowData.package.isDev)
                Chip(
                  label: Text(
                    'dev',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondaryContainer
                    )
                  ),
                  padding: EdgeInsets.zero,
                  color: MaterialStatePropertyAll(Theme.of(context).colorScheme.secondary),
                )
            ]
          )
        ),
        DataCell(
          Padding(
            padding: Pad.top,
            child: Align(
              child: Column(
                children: [
                  Text(
                    rowData.package.version.toString(),
                    textAlign: TextAlign.center
                  ),
                  Text(
                    '(${rowData.package.constraintStr})',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: Theme.of(context).textTheme.labelSmall?.fontSize,
                      color: Theme.of(context).hintColor
                    )
                  )
                ],
              )
            )
          )
        ),
        DataCell(
          Align(
            child: Text(
              rowData.updatedVer?.version.toString() ?? '???',
              textAlign: TextAlign.center
            )
          )
        ),
        DataCell(
          Align(
            child: FutureBuilder<RepoPackage>(
              future: rowData.package.repoPackage,
              builder: (context, snapshot) {
                if(snapshot.error != null) {
                  return Tooltip(
                    message: '${rowData.package.name}\n\n${snapshot.error}',
                    child: const Icon(Icons.error_outline)
                  );
                }
                var repoPackage = snapshot.data;
                if(repoPackage == null)
                  return const CircularProgressIndicator();
                if(!repoPackages.containsKey(rowData.index)) {
                  var storedRepoPackage = repoPackages[rowData.index];
                  if(storedRepoPackage != repoPackage) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      setState(() {
                        repoPackages[rowData.index] = repoPackage;
                      });
                    });
                  }
                }
                var version = repoPackage.latestRelease;
                if(version == null)
                  return const Text('???');
                return Text(version.version.toString());
              },
            )
          )
        )
      ],
      onTap: () {
        ref.read(selectedProvider.notifier).setPackageIndex(rowData.index);
      },
      selected: isSelected
    );
  }
}
