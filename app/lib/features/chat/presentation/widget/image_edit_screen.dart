import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Opens the photo editor on [path] and returns the path of the **edited
/// copy**, or null when the user backs out without saving.
///
/// The result is written to a fresh temp file instead of over [path]: the
/// source is the gallery original, which must never be mutated.
///
/// The chrome is laid out to match WhatsApp, which is what people already know
/// (Achia, comparing the two side by side):
///
///   * the **tools sit at the top**, as icons, not as a labelled row along the
///     bottom;
///   * the **confirm sits at the bottom right**, where a send button belongs
///     and where a thumb reaches;
///   * undo lives with the tools, and only appears once there is something to
///     undo.
///
/// [MainEditorConfigs.tools] is an ordered allow-list, so it doubles as the
/// tool order. Sticker is excluded deliberately: it is on by default but its
/// builder is not, and the toolbar gates the button on the flag alone, so
/// leaving it in ships a button that opens an empty sheet. Tune, blur and
/// filter are left out as surface nobody asked for; add the enum values here if
/// testers want them.
Future<String?> editImageFile(BuildContext context, String path) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder:
          (routeContext) => ProImageEditor.file(
            File(path),
            configs: reactiImageEditorConfigs,
            callbacks: ProImageEditorCallbacks(
              onImageEditingComplete: (bytes) async {
                final out = File(
                  '${Directory.systemTemp.path}/reacti_edit_'
                  '${path.hashCode}_${bytes.length}.jpg',
                );
                await out.writeAsBytes(bytes);
                if (routeContext.mounted) {
                  Navigator.of(routeContext).pop(out.path);
                }
              },
            ),
          ),
    ),
  );
}

/// The editor's configuration, extracted so the layout can be pinned.
///
/// Built inline it was untestable, and a silent revert to the package defaults
/// would put the tools back along the bottom and the confirm back at the top
/// with nothing to catch it.
final ProImageEditorConfigs reactiImageEditorConfigs = ProImageEditorConfigs(
  mainEditor: MainEditorConfigs(
    tools: const [
      SubEditorMode.paint,
      SubEditorMode.text,
      SubEditorMode.emoji,
      SubEditorMode.cropRotate,
    ],
    widgets: MainEditorWidgets(
      appBar: _buildToolBar,
      bottomBar: _buildConfirmBar,
    ),
  ),
);

/// The top bar: close on the left, the tools and undo on the right.
///
/// Replaces the package's default, which puts a confirm tick up here and the
/// tools in a labelled row along the bottom. Both are the opposite way round
/// from WhatsApp, so the two apps' ticks meant different things in the same
/// corner of the screen.
ReactiveAppbar _buildToolBar(
  ProImageEditorState editor,
  Stream<void> rebuildStream,
) {
  return ReactiveAppbar(
    stream: rebuildStream,
    builder:
        (_) => AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Discard',
            icon: const Icon(Icons.close),
            onPressed: editor.closeEditor,
          ),
          actions: [
            // Undo only once there is something to undo. A permanently greyed
            // control is one more thing to read past on a crowded bar.
            if (editor.canUndo)
              IconButton(
                tooltip: 'Undo',
                icon: const Icon(Icons.undo),
                onPressed: editor.undoAction,
              ),
            IconButton(
              tooltip: 'Draw',
              icon: const Icon(Icons.edit_outlined),
              onPressed: editor.openPaintEditor,
            ),
            IconButton(
              tooltip: 'Add text',
              icon: const Icon(Icons.title),
              onPressed: editor.openTextEditor,
            ),
            IconButton(
              tooltip: 'Add emoji',
              icon: const Icon(Icons.emoji_emotions_outlined),
              onPressed: editor.openEmojiEditor,
            ),
            IconButton(
              tooltip: 'Crop or rotate',
              icon: const Icon(Icons.crop_rotate),
              onPressed: editor.openCropRotateEditor,
            ),
          ],
        ),
  );
}

/// The bottom bar: one confirm button, bottom right.
///
/// Where WhatsApp puts send, and where a thumb reaches on a tall phone. The
/// [key] is not optional: the editor measures this bar to work out how far a
/// layer may be dragged, and omitting it makes layers droppable underneath it.
ReactiveWidget _buildConfirmBar(
  ProImageEditorState editor,
  Stream<void> rebuildStream,
  Key key,
) {
  return ReactiveWidget(
    stream: rebuildStream,
    builder:
        (_) => Container(
          key: key,
          color: Colors.black,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'reacti_image_edit_done',
                  onPressed: editor.doneEditing,
                  tooltip: 'Done',
                  child: const Icon(Icons.check),
                ),
              ],
            ),
          ),
        ),
  );
}
