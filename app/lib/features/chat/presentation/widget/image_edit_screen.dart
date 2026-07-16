import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Opens the WhatsApp-style photo editor on [path] — crop/rotate, draw, text
/// and emoji — and returns the path of the **edited copy**, or null when the
/// user backs out without saving.
///
/// The result is written to a fresh temp file instead of over [path]: the
/// source is the gallery original, which must never be mutated.
///
/// [MainEditorConfigs.tools] is an ordered allow-list, so it doubles as the
/// toolbar order. Sticker is excluded deliberately: it is on by default but its
/// builder is not, and the toolbar gates the button on the flag alone — leaving
/// it in ships a button that opens an empty sheet. Tune, blur and filter are
/// left out as toolbar surface nobody asked for; add the enum values here if
/// testers want them.
Future<String?> editImageFile(BuildContext context, String path) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder:
          (routeContext) => ProImageEditor.file(
            File(path),
            configs: const ProImageEditorConfigs(
              mainEditor: MainEditorConfigs(
                tools: [
                  SubEditorMode.cropRotate,
                  SubEditorMode.paint,
                  SubEditorMode.text,
                  SubEditorMode.emoji,
                ],
              ),
            ),
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
