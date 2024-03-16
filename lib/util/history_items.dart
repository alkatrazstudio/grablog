// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:convert';

import 'package:flutter/material.dart';

import '../util/logger.dart';
import '../util/prefs.dart';

class HistoryItem {
  const HistoryItem({
    required this.filename,
    required this.packageManagerName,
    required this.projectName,
  });

  final String filename;
  final String packageManagerName;
  final String projectName;

  HistoryItem.fromJson(Map<String, dynamic> json)
    : filename = json['filename'] as String,
      packageManagerName = json['packageManagerName'] as String,
      projectName = json['projectName'] as String;

  Map<String, String> toJson() => {
    'filename': filename,
    'packageManagerName': packageManagerName,
    'projectName': projectName
  };

  @override
  bool operator ==(Object other) {
    if(other is! HistoryItem)
      return false;
    return filename == other.filename;
  }

  @override
  int get hashCode => filename.hashCode;
}

class HistoryItems extends ValueNotifier<List<HistoryItem>?> {
  static const String historyItemsKey = 'historyItems';
  static const int maxHistoryItems = 50;

  HistoryItems(): super(null) {
    value = get();
  }

  List<HistoryItem> get() {
    var lines = Prefs.instance.getStringList(historyItemsKey) ?? [];
    var items = <HistoryItem>[];
    for(var line in lines) {
      try {
        var itemData = jsonDecode(line) as Map<String, dynamic>;
        var item = HistoryItem.fromJson(itemData);
        items.add(item);
      } catch(e) {
        Log.exception(e, 'history item, parsing line: $line');
      }
    }
    return items;
  }

  Future<void> save(List<HistoryItem> items) async {
    var lines = items.map((item) => jsonEncode(item)).toList();
    await Prefs.instance.setStringList(historyItemsKey, lines);
    value = items;
  }

  Future<void> add(HistoryItem newItem) async {
    var items = get();
    items = items.where((item) => item != newItem).toList();
    items.insert(0, newItem);
    if(items.length > maxHistoryItems)
      items = items.sublist(0, maxHistoryItems);
    await save(items);
  }

  Future<void> remove(HistoryItem itemToRemove) async {
    var items = get();
    items.remove(itemToRemove);
    await save(items);
  }
}

final historyItems = HistoryItems();
