library clear_unused_arb_keys;

import 'dart:convert';
import 'dart:io';

import 'package:console_bars/console_bars.dart';
import 'package:path/path.dart' as p;

/// Searches for the keys with the "L." prefix in the files in the [searchDir]
/// directory and its subdirectories, and removes any keys that are not found
/// from the json file at [jsonPath].
Future<void> searchAndDelete(String searchDir, String jsonPath) async {
  // Load the json file
  final jsonFile = File(jsonPath);
  final data = json.decode(await jsonFile.readAsString()) as Map<String, dynamic>;

  List<File> files = [];

  await for (final file in _findFiles(searchDir)) {
    if (file.uri.pathSegments.where((element) => element.startsWith(".")).isNotEmpty) continue;
    if (!file.uri.pathSegments.last.contains(".dart")) continue;
    files.add(file);
  }

  // Create a set to store the keys that were found
  final foundKeys = <String>{};

  final progressBar = FillingBar(desc: "Searching", total: files.length, time: true, percentage: true, width: 100);

  // Walk through all the files in the search directory and its subdirectories
  for (final file in files) {
    progressBar.increment();
    // Open the file and search for the keys
    final contents = await file.readAsString();
    for (final key in data.keys) {
      if (contents.contains('L.$key')) {
        foundKeys.add(key);
      }
    }
  }

  // Delete the keys that were not found from the json data
  data.removeWhere((key, _) => !foundKeys.contains(key));

  // Save the modified json data
  JsonEncoder encoder = const JsonEncoder.withIndent('  ');
  String prettyprint = encoder.convert(data);
  await jsonFile.writeAsString(prettyprint);
}

/// Returns a stream of [File] objects for all the files in the [dir] directory
/// and its subdirectories.
Stream<File> _findFiles(String dir) async* {
  final directory = Directory(dir);
  if (await directory.exists()) {
    await for (final entity in directory.list()) {
      if (entity is Directory) {
        yield* _findFiles(p.join(dir, entity.path));
      } else if (entity is File) {
        yield entity;
      }
    }
  }
}

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('Usage: search_and_delete JSON_FILE');
    exit(1);
  }

  final searchDir = Directory.current.path;
  final jsonPath = args[0];

  searchAndDelete(searchDir, jsonPath).then((_) => exit(0)).catchError((error) {
    stderr.writeln(error);
    exit(1);
  });
}
