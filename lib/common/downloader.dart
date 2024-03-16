// SPDX-License-Identifier: AGPL-3.0-only

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../util/logger.dart';

class Downloader {
  static const maxAsyncsPerDomain = 5;
  static const waitTimeoutMs = 10;
  static Map<String, int> asyncsCountPerDomain = {};

  static Future<String> get(String url) async {
    var cacheDir = await getApplicationCacheDirectory();
    cacheDir = Directory('${cacheDir.path}/downloads');
    var filename = sha256.convert(utf8.encode(url)).toString();
    var cacheFile = File('${cacheDir.path}/$filename');
    try {
      var fileResult = await getFileContents(cacheFile);
      if(fileResult != null)
        return fileResult;
    } catch(e) {
      Log.warn('fetching cached version of $url: $e');
    }

    var uriObj = Uri.parse(url);
    var result = await waitAndRun(uriObj, () async {
      var content = await http.read(uriObj);
      return content;
    });
    await cacheDir.create();
    try {
      if(await cacheFile.exists())
        await cacheFile.delete();
    } catch(e) {
      Log.exception(e, 'deleting cache file ${cacheFile.path} for $url');
    }
    await cacheFile.writeAsString(result);
    return result;
  }

  static Future<Map<String, dynamic>> getJsonObject(String url) async {
    var json = await get(url);
    var obj = jsonDecode(json);
    return obj;
  }

  static Future<Document> getHtml(String url) async {
    var html = await get(url);
    var doc = parse(html);
    return doc;
  }

  static Future<String?> getFileContents(File file) async {
    var modTime = await file.lastModified();
    var now = DateTime.now();
    var startOfDay = DateTime(now.year, now.month, now.day);
    if(modTime.isBefore(startOfDay))
      return null;
    var content = await file.readAsString();
    return content;
  }

  static Future<T> waitAndRun<T>(Uri url, Future<T> Function() f) async {
    if(!asyncsCountPerDomain.containsKey(url.host))
      asyncsCountPerDomain[url.host] = 0;

    // simulating spin-lock semaphore
    while(asyncsCountPerDomain[url.host]! >= maxAsyncsPerDomain) {
       await Future.delayed(const Duration(milliseconds: waitTimeoutMs));
    }

    asyncsCountPerDomain[url.host] = asyncsCountPerDomain[url.host]! + 1;
    try {
      Log.info('Downloading: $url');
      var result = await f();
      asyncsCountPerDomain[url.host] = asyncsCountPerDomain[url.host]! - 1;
      return result;
    } catch(e) {
      asyncsCountPerDomain[url.host] = asyncsCountPerDomain[url.host]! - 1;
      Log.exception(e, 'downloading $url');
      rethrow;
    }
  }
}
