// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';

import '../common/package_manager.dart';
import '../common/state.dart';
import '../util/cli_args.dart';
import '../util/dialogs.dart' as dialogs;
import '../util/history_items.dart';
import '../util/logger.dart';
import '../widgets/central_pane.dart';
import '../widgets/history_items_list.dart';
import '../widgets/logs_drawer.dart';
import '../widgets/manager_selector.dart';

class Home extends StatefulWidget {
  const Home(this.cliArgs);

  final CliArgs cliArgs;

  @override
  State<Home> createState() => HomeState();
}

class HomeState extends State<Home> {
  List<PackageManager> managers = [];
  PackageManager? manager;
  String? latestDir;
  bool cliArgsHandled = false;

  String? getInitialDirectory() {
    if(latestDir != null)
      return latestDir!;
    if(manager != null)
      return dirname(manager!.filename);
    var items = historyItems.get();
    var latestItem = items.firstOrNull;
    if(latestItem != null)
      return dirname(latestItem.filename);
    return null;
  }

  Future<void> chooseManager(PackageManager newManager, WidgetRef? ref) async {
    await historyItems.add(HistoryItem(
      filename: newManager.filename,
      packageManagerName: newManager.name,
      projectName: newManager.projectName
    ));
    setState(() {
      manager = newManager;
      managers = [];
      ref?.read(selectedProvider.notifier).reset();
    });
  }

  Future<void> openFromDirOrFile(BuildContext context, WidgetRef? ref, String filename) async {
    try {
      var newManagers = await PackageManager.fromDirOrFile(filename);
      if(newManagers.length == 1) {
        await chooseManager(newManagers.first, ref);
      } else {
        setState(() {
          manager = null;
          managers = newManagers;
        });
        if(newManagers.isEmpty) {
          if(context.mounted)
            dialogs.alert(context, 'No supported lock files found in $filename');
        }
      }
    } catch(e) {
      Log.exception(e, 'opening manager from file: $filename');
      if(context.mounted)
        await dialogs.alert(context, '$filename: ${e.toString()}');
    }
  }

  Future<void> openFromFile(BuildContext context, WidgetRef ref, String filename) async {
    await openFromDirOrFile(context, ref, filename);
    latestDir = dirname(filename);
  }

  Future<void> open(BuildContext context, WidgetRef ref) async {
    try {
      var initialDirectory = getInitialDirectory();
      Log.info('initial dir: $initialDirectory');
      var dir = await getDirectoryPath(initialDirectory: initialDirectory);
      if(dir == null)
        return;
      Log.info('selected dir: $initialDirectory');
      latestDir = dir;
      if(context.mounted)
        await openFromDirOrFile(context, ref, dir);
      else
        throw Exception('No context for openFromDirOrFile');
    } catch(e) {
      Log.exception(e, 'open dialog');
      if(context.mounted)
        dialogs.alert(context, e.toString());
    }
  }

  Widget centerWidget() {
    if(manager == null) {
      if(managers.isEmpty) {
        return Consumer(
          builder: (context, ref, child) {
            return HistoryItemsList(
              asDropdown: false,
              onFileSelected: (filename) => openFromFile(context, ref, filename)
            );
          }
        );
      } else {
        return Consumer(
          builder: (context, ref, child) {
            return ManagerSelector(
              managers: managers,
              onSelected: (newManager) {
                chooseManager(newManager, ref);
              }
            );
          }
        );
      }
    }
    return CentralPane(manager: manager!);
  }

  @override
  Widget build(context) {
    if(!cliArgsHandled) {
      cliArgsHandled = true;
      var path = widget.cliArgs.path;
      if(path != null)
        WidgetsBinding.instance.addPostFrameCallback((_) => openFromDirOrFile(context, null, path));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          manager == null
            ? 'GrabLog'
            : '${manager!.projectName} [${manager!.name}]'
        ),
        actions: [
          Consumer(
            builder: (context, ref, child) {
              return ElevatedButton(
                onPressed: () async {
                  open(context, ref);
                },
                child: const Text('Open...')
              );
            }
          ),
          Consumer(
            builder: (context, ref, child) {
              return HistoryItemsList(
                asDropdown: true,
                onFileSelected: (filename) => openFromFile(context, ref, filename)
              );
            }
          ),
          Consumer(
            builder: (context, ref, child) {
              return ElevatedButton(
                onPressed: manager == null ? null : () async {
                  try {
                    var newManager = await manager!.loadNew();
                    setState(() {
                      manager = newManager;
                      ref.read(selectedProvider.notifier).reset();
                    });
                  } catch(e) {
                    Log.exception(e, 'reloading manager: ${manager?.filename}');
                    if(context.mounted)
                      await dialogs.alert(context, '${manager!.filename}: ${e.toString()}');
                  }
                },
                child: const Text('Reload')
              );
            }
          ),
          Builder(
            builder: (context) {
              return IconButton(
                onPressed: () {
                  Scaffold.of(context).openEndDrawer();
                },
                icon: const Icon(Icons.summarize),
              );
            }
          )
        ],
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      endDrawer: const LogsDrawer(),
      body: Center(
        child: centerWidget()
      )
    );
  }
}
