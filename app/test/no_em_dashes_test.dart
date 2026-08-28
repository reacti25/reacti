// No em dashes in anything the user reads.
//
// Achia, twice now: "remove the long dash", then "take it as a rule: no long
// dashes anywhere to be found in the app". It reads as machine-written to her,
// and a rule stated once tends to decay back — so it is enforced here rather
// than remembered.
//
// Scoped to STRING LITERALS. Comments and docs are for whoever reads the code,
// not for the user, and rewriting those would be a large diff nobody sees.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The code part of [line], with any line comment removed.
///
/// Trailing comments count too, not just whole-line ones: the first two this
/// caught were both `code; // note — like this`.
///
/// Deliberately crude. It skips a `//` preceded by a colon so `https://` inside
/// a string survives, and it does not understand `/* */` blocks or a `//` that
/// is genuinely inside a string literal. The repo uses line comments
/// throughout, and the cost of being wrong here is one rewritten sentence.
String _codePart(String line) {
  for (var i = 0; i < line.length - 1; i++) {
    if (line[i] != '/' || line[i + 1] != '/') continue;
    if (i > 0 && line[i - 1] == ':') continue;
    return line.substring(0, i);
  }
  return line;
}

void main() {
  test('no user-facing copy contains an em dash', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // Generated files are not ours to rewrite.
      if (entity.path.contains('.g.dart') ||
          entity.path.contains(RegExp(r'[\/]gen[\/]'))) {
        continue;
      }

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = _codePart(lines[i]);
        if (!code.contains('—')) continue;
        // Only lines that also carry a quote can be showing text to anyone.
        if (!code.contains("'") && !code.contains('"')) continue;
        offenders.add('${entity.path}:${i + 1}  ${lines[i].trim()}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Em dashes in user-facing text. Use a comma, a full stop or a '
          'rewrite:\n${offenders.join('\n')}',
    );
  });
}
