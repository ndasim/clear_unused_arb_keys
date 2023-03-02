library clear_unused_arb_keys;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:console_bars/console_bars.dart';
import 'package:path/path.dart' as p;
import 'package:translator/translator.dart';

/// Searches for the keys with the "L." prefix in the files in the [searchDir]
/// directory and its subdirectories, and removes any keys that are not found
/// from the json file at [jsonPath].
Future<void> optimizeAndTranslate(String searchDir, String arbFolder, String baseLanguage) async {
  // await optimize(searchDir, arbFolder, baseLanguage);
  await translate(searchDir, arbFolder, baseLanguage);

  await Future.delayed(const Duration(milliseconds: 100));
}

Future<void> optimize(String searchDir, String arbFolder, String baseLanguage) async {
  final baseArbFile = File(searchDir + Platform.pathSeparator + arbFolder + Platform.pathSeparator + "intl_$baseLanguage.arb");
  final baseLanguageKeys = json.decode(await baseArbFile.readAsString()) as Map<String, dynamic>;

  List<File> files = [];

  await for (final file in _findFiles(searchDir)) {
    if (file.uri.pathSegments.where((element) => element.startsWith(".")).isNotEmpty) continue;
    if (!file.uri.pathSegments.last.contains(".dart")) continue;
    files.add(file);
  }

  // Create a set to store the keys that were found
  final foundKeys = <String>{};

  final progressBar = FillingBar(desc: "Searching", total: files.length, time: true, percentage: true, width: 20);

  // Walk through all the files in the search directory and its subdirectories
  for (final file in files) {
    progressBar.increment();
    // Open the file and search for the keys
    final contents = await file.readAsString();
    for (final key in baseLanguageKeys.keys) {
      if (contents.contains('L.$key')) {
        foundKeys.add(key);
      }
    }
  }

  // Delete the keys that were not found from the json baseLanguageKeys
  baseLanguageKeys.removeWhere((key, _) => !foundKeys.contains(key));

  // Save the modified json baseLanguageKeys
  JsonEncoder encoder = const JsonEncoder.withIndent('  ');
  String prettyprint = encoder.convert(baseLanguageKeys);
  await baseArbFile.writeAsString(prettyprint);
}

Future<void> translate(String searchDir, String arbFolder, String baseLanguage) async {
  // Load the json file
  final baseArbFile = File(searchDir + Platform.pathSeparator + arbFolder + Platform.pathSeparator + "intl_$baseLanguage.arb");
  final baseLanguageKeys = json.decode(await baseArbFile.readAsString()) as Map<String, dynamic>;

  // Find arb files for translation
  List<File> languageArbs = [];
  await for (final file in _findFiles(searchDir + Platform.pathSeparator + arbFolder)) {
    if (file.uri.pathSegments.where((element) => element.startsWith(".")).isNotEmpty) continue;
    if (!file.uri.pathSegments.last.contains(".arb")) continue;
    if (file.uri.pathSegments.last.contains(baseLanguage + ".arb")) continue;
    languageArbs.add(file);
  }

  GoogleTranslator translator = GoogleTranslator();

  for (File arbFile in languageArbs) {
    String targetLanguageCode = arbFile.path.split(Platform.pathSeparator).last.split(".").first.split("_").last; // TODO: Handle edge cases
    Map<String, dynamic> targetLanguageKeys = json.decode(await arbFile.readAsString()) as Map<String, dynamic>;

    Future(() async {
      Future<void> translateKey(String key) async {
        print(key + " " + baseLanguage + " " + targetLanguageCode);
        Completer completer = Completer();

        translator.translate(baseLanguageKeys[key], from: baseLanguage, to: targetLanguageCode).catchError((e) {
          print(e);
          completer.complete();
        }).then((translated) {
          print(translated.text);
          targetLanguageKeys[key] = translated.text;
          completer.complete();
        });

        await completer.future;
      }

      // Find differences between targetLanguageKeys and baseLanguageKeys
      Set missingKeys = baseLanguageKeys.keys.toSet().difference(targetLanguageKeys.keys.toSet());
      List<Future> translateJobs = [];
      for (String key in missingKeys) {
        await translateKey(key);
      }

      // Translate all keys
      // await Future.wait(translateJobs).catchError((e) {
      //   print(e);
      //   return null;
      // });

      // Save file
      JsonEncoder encoder = const JsonEncoder.withIndent('  ');
      String prettyprint = encoder.convert(targetLanguageKeys);
      await arbFile.writeAsString(prettyprint);
      print("${arbFile.path} translated with ${translateJobs.length} keys");
    });
  }
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

void main(List<String> args) async {
  final searchDir = Directory.current.path;
  final arbFolder = args.length > 0 ? args[0] : "lib/l10n";
  final baseLanguage = args.length > 1 ? args[1] : "en";

  await optimizeAndTranslate(searchDir, arbFolder, baseLanguage).then((_) => exit(0)).catchError((error) {
    stderr.writeln(error);
    exit(1);
  });
}
