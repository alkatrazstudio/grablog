// SPDX-License-Identifier: AGPL-3.0-only

import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../common/changelog.dart';
import '../common/package.dart';
import '../common/state.dart';
import '../widgets/pad.dart';

class ChangelogsPane extends StatelessWidget {
  const ChangelogsPane({
    required this.package
  });

  final Package package;

  @override
  Widget build(context) {
    return FutureBuilder(
      key: ValueKey(package),
      future: package.repoPackage,
      builder: (context, snapshot) {
        var error = snapshot.error;
        var repoPackage = snapshot.data;
        if(repoPackage == null && error == null) {
          return const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: PackageInfoPanel(package: package)
                )
              ]
            ),
            if(repoPackage != null)
              ChangelogsSelector(repoPackage: repoPackage),
            if(repoPackage != null)
              Expanded(
                child: ChangelogView(repoPackage: repoPackage)
              ),
            if(error != null)
              Padding(
                padding: Pad.horizontal,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    error.toString(),
                    textAlign: TextAlign.start
                  )
                )
              )
          ],
        );
      },
    );
  }
}

class ChangelogsListener extends StatelessWidget {
  const ChangelogsListener({
    required this.repoPackage,
    required this.builder
  });

  final RepoPackage repoPackage;
  final Function(List<Changelog>? changelogs, int changelogIndex, BuildContext context, WidgetRef ref) builder;

  @override
  Widget build(context) {
    return ValueListenableBuilder(
      valueListenable: repoPackage.changelogs,
      builder: (context, changelogs, child) {
        return Consumer(
          builder: (context, ref, child) {
            var curIndex = ref.watch(selectedProvider).changelogIndex;
            return builder(changelogs, curIndex, context, ref);
          }
        );
      }
    );
  }
}

class ChangelogsSelector extends StatelessWidget {
  const ChangelogsSelector({
    required this.repoPackage
  });

  final RepoPackage repoPackage;

  @override
  Widget build(context) {
    return ChangelogsListener(
      repoPackage: repoPackage,
      builder: (changelogs, curIndex, context, ref) {
        if(changelogs == null)
          return const CircularProgressIndicator();
        if(changelogs.isEmpty)
          return const Text('No changelogs found.');
        return SegmentedButton(
          segments: changelogs.mapIndexed((changelogIndex, changelog) {
            return ButtonSegment(
              value: changelogIndex,
              label: Text(changelog.name),
            );
          }).toList(),
          selected: {curIndex},
          onSelectionChanged: (sel) {
            ref.read(selectedProvider.notifier).setChangelogIndex(sel.first);
          },
          showSelectedIcon: false,
        );
      },
    );
  }
}

class ChangelogView extends StatelessWidget {
  const ChangelogView({
    required this.repoPackage
  });

  final RepoPackage repoPackage;

  @override
  Widget build(context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: ChangelogsListener(
        repoPackage: repoPackage,
        builder: (changelogs, curIndex, context, ref) {
          if(changelogs == null || curIndex >= changelogs.length)
            return const SizedBox.shrink();
          var changelog = changelogs[curIndex];
          return Column(
            children: [
              Padding(padding:
                const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  child: Text(changelog.url),
                  onTap: () {
                    launchUrlString(changelog.url);
                  },
                )
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: ValueListenableBuilder(
                    valueListenable: changelog.contentSource.loadingNotification,
                    builder: (context, isLoading, child) {
                      return Column(
                        children: [
                          changelog.contentSource.widget,
                          if(isLoading)
                            const CircularProgressIndicator()
                          else if(changelog.contentSource.canLoadMore)
                            ElevatedButton(
                              onPressed: () {
                                changelog.contentSource.loadMore();
                              },
                              child: const Text('load more...')
                            )
                        ],
                      );
                    },
                  )
                )
              )
            ],
          );
        }
      )
    );
  }
}

class PackageInfoPanel extends StatelessWidget {
  const PackageInfoPanel({
    required this.package
  });

  final Package package;

  @override
  Widget build(context) {
    return Card(
      key: ValueKey(package),
      child: Padding(
        padding: Pad.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  package.name,
                  style: TextStyle(
                    fontSize: Theme.of(context).textTheme.headlineMedium?.fontSize
                  )
                ),
                if(package.isDev)
                  Padding(
                    padding: Pad.left,
                    child: Chip(
                      label: Text(
                        'dev',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSecondaryContainer
                        )
                      ),
                      padding: EdgeInsets.zero,
                      color: MaterialStatePropertyAll(Theme.of(context).colorScheme.secondary),
                    )
                  ),
                Padding(
                  padding: Pad.left,
                  child: Chip(
                    label: Text(package.version.toString()),
                    color: MaterialStatePropertyAll(Theme.of(context).colorScheme.secondaryContainer),
                    padding: EdgeInsets.zero,
                  )
                )
              ]
            ),
            FutureBuilder(
              future: package.repoPackage,
              builder: (context, snapshot) {
                var repoPackage = snapshot.data;
                if(repoPackage == null)
                  return const SizedBox.shrink();
                return Column(
                  children: repoPackage.links.where((link) => link.isVisibleToUser).map(
                    (link) => PackageInfoLink(link: link)
                  ).toList()
                );
              },
            )
          ],
        )
      )
    );
  }
}

class PackageInfoLink extends StatelessWidget {
  const PackageInfoLink({
    required this.link
  });

  final PackageLink link;

  @override
  Widget build(context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: Pad.right,
          child: Text(
            '${link.name}:',
            style: const TextStyle(
              fontWeight: FontWeight.bold
            ),
          ),
        ),
        Expanded(
          child: InkWell(
            onTap: () => launchUrlString(link.url),
            child: Text(link.url),
          )
        )
      ],
    );
  }
}
