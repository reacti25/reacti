// The photo editor's layout, which is WhatsApp's and not the package's.
//
// Achia, comparing the two side by side: Reacti put the tools in a labelled row
// along the BOTTOM and a confirm tick at the TOP; WhatsApp does the opposite.
// Both ticks therefore sat in the same corner meaning different things.
//
// The layout comes from builders handed to `pro_image_editor`. Nothing about a
// missing builder fails loudly — the package quietly falls back to its own
// chrome — so what is checked here is that ours are still wired, and that the
// tool list has not drifted.

import 'package:flutter_test/flutter_test.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:reacti_app/features/chat/presentation/widget/image_edit_screen.dart';

void main() {
  final mainEditor = reactiImageEditorConfigs.mainEditor;

  test('the tools are ours, in order, and sticker stays out', () {
    // Order is the toolbar order. Sticker is enabled by default in the package
    // but its builder is not, so leaving it in ships a button that opens an
    // empty sheet.
    expect(mainEditor.tools, [
      SubEditorMode.paint,
      SubEditorMode.text,
      SubEditorMode.emoji,
      SubEditorMode.cropRotate,
    ]);
    expect(mainEditor.tools, isNot(contains(SubEditorMode.sticker)));
  });

  test('both bars are overridden, not left to the package', () {
    // A null here is not an error at runtime, it is the old layout coming back
    // silently: tools along the bottom, confirm at the top.
    expect(
      mainEditor.widgets.appBar,
      isNotNull,
      reason: 'the tools belong at the top',
    );
    expect(
      mainEditor.widgets.bottomBar,
      isNotNull,
      reason: 'the confirm belongs at the bottom right',
    );
  });
}
