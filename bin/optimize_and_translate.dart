library optimize_and_translate;

import 'dart:io';

import 'package:optimize_and_translate/optimize_and_translate.dart';

void main(List<String> args) async {
  final searchDir = Directory.current.path;
  final arbFolder = args.length > 0 ? args[0] : "lib/l10n";
  final baseLanguage = args.length > 1 ? args[1] : "en";

  await optimizeAndTranslate(searchDir, arbFolder, baseLanguage).then((_) => exit(0)).catchError((error) {
    print(error);
    exit(1);
  });
}
