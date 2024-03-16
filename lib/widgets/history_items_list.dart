// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';

import 'package:flutter_html/flutter_html.dart';
import 'package:path/path.dart';

import '../util/history_items.dart';
import '../widgets/pad.dart';
import '../widgets/search_field.dart';

class HistoryItemsList extends StatefulWidget {
  const HistoryItemsList({
    required this.onFileSelected,
    required this.asDropdown
  });

  final Function(String) onFileSelected;
  final bool asDropdown;

  @override
  State<HistoryItemsList> createState() => HistoryItemsListState();
}

class HistoryItemsListState extends State<HistoryItemsList> {
  var recentsFocusNode = FocusNode();
  var searchController = TextEditingController();
  var dropdownController = MenuController();
  var search = '';

  static const double itemWidth = 850;

  List<Widget> itemButtons(BuildContext ctx, List<HistoryItem> items) {
    items = search.isEmpty
      ? items
      : items.where((item) =>
          item.filename.toLowerCase().contains(search)
          ||
          item.projectName.toLowerCase().contains(search)
          ||
          item.packageManagerName.toLowerCase().contains(search)
      ).toList();

    return items.map((item) => SizedBox(
      width: widget.asDropdown ? itemWidth : null,
      child: TextButton(
        child: Padding(
          padding: Pad.bottom,
          child: Row(
            children: [
              Chip(
                color: MaterialStatePropertyAll(Theme.of(ctx).colorScheme.inversePrimary),
                labelPadding: EdgeInsets.zero,
                label: Text(
                  '${item.projectName} [${item.packageManagerName}]',
                  style: TextStyle(
                    fontSize: FontSize.xLarge.emValue,
                  ),
                )
              ),
              const SizedBox(width: Pad.pad),
              Expanded(
                child: Text(
                  dirname(item.filename),
                  style: TextStyle(
                    color: Theme.of(ctx).colorScheme.onPrimaryContainer
                  ),
                )
              ),
              IconButton(
                onPressed: () async {
                  await historyItems.remove(item);
                },
                icon: Icon(Icons.delete_forever, color: Theme.of(ctx).colorScheme.secondary)
              )
            ],
          ),
        ),
        onPressed: () {
          widget.onFileSelected(item.filename);
          if(widget.asDropdown)
            dropdownController.close();
        }
      )
    )).toList();
  }

  Widget searchField() {
    return Padding(
      padding: Pad.bottom,
      child: SearchField(
        onChanged: (text) => setState(() => search = text),
      )
    );
  }

  Widget noItemsWidget() {
    return Padding(
      padding: Pad.all,
      child: const Text('- no recent items found - '),
    );
  }

  Widget menuAnchor(BuildContext context, List<HistoryItem>? items) {
    var hItems = items ?? [];
    return MenuAnchor(
      childFocusNode: recentsFocusNode,
      menuChildren: hItems.isEmpty ? [
        noItemsWidget()
      ] : [
        SizedBox(
          width: itemWidth,
          child: searchField()
        ),
        ...itemButtons(context, hItems)
      ],
      controller: dropdownController,
      builder: (context, controller, child) {
        return IconButton(
          focusNode: recentsFocusNode,
          onPressed: () {
            if(controller.isOpen)
              controller.close();
            else
              controller.open();
          },
          icon: const Icon(Icons.history)
        );
      },
    );
  }

  Widget listView(BuildContext context, List<HistoryItem>? items) {
    if(items == null)
      return const CircularProgressIndicator();
    if(items.isEmpty)
      return noItemsWidget();
    return Column(
      children: [
        searchField(),
        Expanded(
          child: ListView(
            children: itemButtons(context, items),
          )
        )
      ],
    );
  }

  @override
  Widget build(context) {
    return ValueListenableBuilder(
      valueListenable: historyItems,
      builder: (context, items, _) {
        if(widget.asDropdown)
          return menuAnchor(context, items);
        return listView(context, items);
      }
    );
  }
}
