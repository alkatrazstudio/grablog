// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

import '../util/logger.dart';
import '../util/prefs.dart';

Future<void> alert(BuildContext context, String msg) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        content: Text(msg),
        actions: <Widget>[
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

Future<bool> confirm(BuildContext context, String msg) async {
  var result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        content: Text(msg),
        actions: <Widget>[
          TextButton(
            child: const Text('No'),
            onPressed: () {
              Navigator.of(context).pop(false);
            },
          ),
          TextButton(
            child: const Text('Yes'),
            onPressed: () {
              Navigator.of(context).pop(true);
            },
          ),
        ],
      );
    },
  );
  return result ?? false;
}

Future<File?> saveFile({
  required BuildContext context,
  required String name,
  required String suggestedNamePrefix,
  required String suggestedNameExtension,
  required Future<String> Function() getContent,
}) async {
  var prefsKey = 'saveDialog.$name.path';
  var initialDirectory = Prefs.instance.getString(prefsKey);
  final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  var basename = '${suggestedNamePrefix}_$timestamp';
  basename = basename.replaceAll(RegExp(r'[^a-zA-Z0-9-]'), '_').toLowerCase();
  var suggestedName = '$basename.$suggestedNameExtension';
  while(true) {
    var location = await file_selector.getSaveLocation(
      initialDirectory: initialDirectory,
      suggestedName: suggestedName
    );
    if(location == null)
      return null;
    initialDirectory = path.dirname(location.path);
    await Prefs.instance.setString(prefsKey, initialDirectory);
    var file = File(location.path);
    if(await file.exists()) {
      if(context.mounted) {
        if(!await confirm(context, 'File already exists. Overwrite?\n\n${location.path}')) {
          continue;
        }
      }
    }

    try {
      var content = await getContent();
      await file.writeAsString(content);
      return file;
    } catch(e) {
      var msg = 'Saving to ${file.path}';
      Log.exception(e, msg);
      if(context.mounted)
        await alert(context, '$msg: $e');
      return null;
    }
  }
}
