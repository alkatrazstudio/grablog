// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:convert';

import 'package:html/dom.dart';
import 'package:path/path.dart';

import '../common/changelog.dart';
import '../common/content.dart';
import '../common/downloader.dart';
import '../common/site.dart';
import '../content_source/github_releases.dart';
import '../util/logger.dart';

class GitHubPageMeta {
  const GitHubPageMeta({
    required this.branch,
    required this.filenames
  });

  final String branch;
  final List<String> filenames;
}

class GitHub extends Site {
  GitHub({
    required super.author,
    required super.project
  }): super(name: 'GitHub');

  static const basenames = ['CHANGELOG'];

  GitHubPageMeta? pageMeta;

  static GitHub? byUrl(String url) {
    Uri urlObj;
    try {
      urlObj = Uri.parse(url);
    } catch(e) {
      Log.exception(e, 'parsing $url');
      var m = RegExp(r'^git@github\.com:([^/]+)/([^.]+)\.git$').firstMatch(url);
      if(m != null) {
        return GitHub(
          author: m.group(1)!,
          project: m.group(2)!
        );
      }
      return null;
    }

    if(urlObj.host != 'github.com')
      return null;
    if(urlObj.pathSegments.length < 2)
      return null;
    var author = urlObj.pathSegments[0];
    var project = withoutExtension(urlObj.pathSegments[1]);
    return GitHub(
      author: author,
      project: project
    );
  }

  Future<Document> getRootHtml() async {
    var rootUrl = 'https://github.com/$author/$project';
    var doc = await Downloader.getHtml(rootUrl);
    return doc;
  }

  Future<GitHubPageMeta> getPageMeta() async {
    if(pageMeta != null)
      return pageMeta!;
    var doc = await getRootHtml();
    var scripts = doc.querySelectorAll(r'script').reversed;
    for(var script in scripts) {
      try {
        var embeddedData = jsonDecode(script.text);
        var branch = embeddedData['props']['initialPayload']['repo']['defaultBranch'] as String;

        var filenames = <String>[];
        try {
          var treeItems = embeddedData['props']['initialPayload']['tree']['items'] as List<dynamic>;
          for(var (index, treeItem) in treeItems.indexed) {
            try {
              treeItem = treeItem as Map<String, dynamic>;
              var filename = treeItem['path'] as String;
              filenames.add(filename);
            } catch(e) {
              Log.exception(e, 'GitHub: $baseUrl: fetching tree.items[$index].path');
            }
          }
        } catch(e) {
          Log.exception(e, 'GitHub: $baseUrl: fetching tree.items');
        }

        pageMeta = GitHubPageMeta(
          branch: branch,
          filenames: filenames
        );
        return pageMeta!;
      } catch(e) {
      }
    }
    throw Exception('Can\'t determine the default branch');
  }

  Future<List<String>> getTopLevelFilenames() async {
    var meta = await getPageMeta();
    return meta.filenames;
  }

  @override
  Future<List<Changelog>> fetchChangelogs() async {
    var changelogs = <Changelog>[];
    var meta = await getPageMeta();
    for(var filename in meta.filenames) {
      var fileBasename = basenameWithoutExtension(filename);
      if(!basenames.any((name) => fileBasename.toUpperCase() == name))
        continue;
      var url = 'https://raw.githubusercontent.com/$author/$project/${meta.branch}/$filename';
      var contentSource = ContentSource.byFilenameAndUrl(filename, url);
      if(contentSource == null)
        continue;
      var userUrl = 'https://github.com/$author/$project/blob/${meta.branch}/$filename';
      var changelog = Changelog(name: 'GitHub - $filename', url: userUrl, contentSource: contentSource);
      changelogs.add(changelog);
    }

    var releasesUrl = 'https://github.com/$author/$project/releases';
    var releasesChangelog = Changelog(
      name: 'GitHub - Releases',
      url: releasesUrl,
      contentSource: GitHubReleasesContentSource(url: releasesUrl)
    );
    changelogs.add(releasesChangelog);
    return changelogs;
  }

  @override
  String get baseUrl => 'https://github.com/$author/$project';
}
