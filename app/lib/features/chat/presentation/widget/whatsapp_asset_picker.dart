import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'image_edit_screen.dart';

/// Result of the WhatsApp-style picker: the chosen assets, the one caption
/// typed inline in the picker's bottom bar, and any edited copies.
class WhatsAppPickResult {
  const WhatsAppPickResult(this.assets, this.caption, this.edits);

  final List<AssetEntity> assets;
  final String caption;

  /// Path of the edited copy, keyed by [AssetEntity.id], for the assets the
  /// user ran through the photo editor. Assets left untouched are absent.
  final Map<String, String> edits;

  /// The file to actually send for [assetId]: the edited copy when the user
  /// drew on it, otherwise the gallery original at [originalPath].
  String pathFor(String assetId, String originalPath) =>
      edits[assetId] ?? originalPath;
}

/// How much of the screen the picker sheet covers. WhatsApp leaves the top of
/// the conversation visible behind it.
///
/// ponytail: a constant, not a draggable sheet. WhatsApp lets you drag the
/// sheet to full height; that needs DraggableScrollableSheet wired into the
/// picker's own grid scroll controller. Add it if testers ask for it.
const double _sheetHeightFactor = 0.72;

/// Lays the picker out as a WhatsApp-style **bottom sheet** — the conversation
/// stays visible above it behind a scrim — rather than a full-screen takeover.
///
/// Two MediaQuery adjustments are load-bearing:
/// * `removeTop`: the picker reserves room for the status bar, which inside a
///   sheet would be dead space above its own app bar.
/// * `removeViewInsets`: the keyboard is already accounted for by the padding
///   below, so the picker's own Scaffold must not subtract it a second time.
Widget _asSheet(BuildContext context, Widget picker) {
  return Align(
    alignment: Alignment.bottomCenter,
    child: Padding(
      // Ride above the keyboard when the caption field takes focus.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: _sheetHeightFactor,
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: MediaQuery.removeViewInsets(
              context: context,
              removeBottom: true,
              child: picker,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Opens a WhatsApp-style media picker: a dense multi-select grid in a **bottom
/// sheet over the chat**, with an **inline "Add a caption…" + send bar** and an
/// edit filmstrip (no separate confirm button and no separate review page).
///
/// Built on `wechat_assets_picker` by subclassing its default delegate — so it
/// reuses the package's album/permission/paging engine and only restyles the
/// bottom bar and the route. Returns null when the user backs out without
/// sending, including by tapping the scrim.
Future<WhatsAppPickResult?> pickWhatsAppMedia(
  BuildContext context, {
  required Color accent,
  required Color onAccent,
  int maxAssets = 30,
}) async {
  final caption = TextEditingController();
  const permissionOption = PermissionRequestOption(
    androidPermission: AndroidPermission(
      type: RequestType.common,
      mediaLocation: false,
    ),
  );
  final permission = await AssetPicker.permissionCheck(
    requestOption: permissionOption,
  );
  if (!context.mounted) {
    caption.dispose();
    return null;
  }

  final provider = DefaultAssetPickerProvider(
    maxAssets: maxAssets,
    requestType: RequestType.common,
  );
  final delegate = _WhatsAppPickerDelegate(
    provider: provider,
    initialPermission: permission,
    accent: accent,
    onAccent: onAccent,
    caption: caption,
    pickerTheme: AssetPicker.themeData(accent),
  );

  final barrierLabel =
      MaterialLocalizations.of(context).modalBarrierDismissLabel;
  final assets = await AssetPicker.pickAssetsWithDelegate(
    context,
    delegate: delegate,
    permissionRequestOption: permissionOption,
    // Swap the package's default full-screen route for a sheet over the chat.
    pageRouteBuilder:
        (picker) => AssetPickerPageRoute<List<AssetEntity>>(
          builder: (routeContext) => _asSheet(routeContext, picker),
          opaque: false, // let the conversation show through
          barrierColor: Colors.black54,
          barrierDismissible: true, // tap the scrim to dismiss, like WhatsApp
          barrierLabel: barrierLabel,
        ),
  );
  final text = caption.text.trim();
  final edits = delegate.edits.value;
  caption.dispose();
  delegate.edits.dispose();
  if (assets == null || assets.isEmpty) return null;
  return WhatsAppPickResult(assets, text, edits);
}

/// Default picker delegate with a WhatsApp-style bottom bar.
class _WhatsAppPickerDelegate extends DefaultAssetPickerBuilderDelegate {
  _WhatsAppPickerDelegate({
    required super.provider,
    required super.initialPermission,
    required super.pickerTheme,
    required this.accent,
    required this.onAccent,
    required this.caption,
  }) : super(
         gridCount: 4,
         // Without this the package falls back to its Chinese text delegate.
         textDelegate: const EnglishAssetPickerTextDelegate(),
       );

  final Color accent;
  final Color onAccent;
  final TextEditingController caption;

  /// Edited-copy path per asset id. A [ValueNotifier] (rebuilt by assigning a
  /// new map) because the picker's own provider knows nothing about edits and
  /// so won't notify the thumbnail when one lands.
  final ValueNotifier<Map<String, String>> edits =
      ValueNotifier<Map<String, String>>(const {});

  // The default confirm lives in the bottom bar we replace; hide it anywhere
  // else it might render.
  @override
  Widget confirmButton(BuildContext context) => const SizedBox.shrink();

  // WhatsApp selects on a tap anywhere on the tile (no tap-to-preview), with a
  // dim overlay on the selected ones. Put the toggle on the full-cell backdrop.
  @override
  Widget selectedBackdrop(BuildContext context, int index, AssetEntity asset) {
    return Positioned.fill(
      child: Consumer<DefaultAssetPickerProvider>(
        builder: (context, p, _) {
          final isSelected = p.selectedAssets.contains(asset);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => selectAsset(context, asset, index, isSelected),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              color: isSelected ? Colors.black45 : Colors.transparent,
            ),
          );
        },
      ),
    );
  }

  // WhatsApp-style selection badge: a numbered green circle (the selection
  // order), an empty circle when unselected. Non-interactive so the tile-tap
  // above handles toggling.
  @override
  Widget selectIndicator(BuildContext context, int index, AssetEntity asset) {
    return IgnorePointer(
      child: Selector<DefaultAssetPickerProvider, List<AssetEntity>>(
        selector: (_, p) => p.selectedAssets.toList(),
        builder: (context, selected, _) {
          final order = selected.indexOf(asset);
          final isSelected = order >= 0;
          return Align(
            alignment: AlignmentDirectional.topEnd,
            child: Container(
              margin: EdgeInsets.all(6.w),
              width: 22.w,
              height: 22.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? accent : Colors.black26,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child:
                  isSelected
                      ? Text(
                        '${order + 1}',
                        style: TextStyle(
                          color: onAccent,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      )
                      : null,
            ),
          );
        },
      ),
    );
  }

  /// Opens the photo editor on [asset] and remembers the edited copy, so the
  /// send path uploads the drawn-on version instead of the gallery original.
  Future<void> _openEditor(BuildContext context, AssetEntity asset) async {
    final source = edits.value[asset.id] ?? (await asset.file)?.path;
    if (source == null || !context.mounted) return;
    final result = await editImageFile(context, source);
    if (result == null) return; // backed out — keep whatever we had
    edits.value = {...edits.value, asset.id: result};
  }

  /// Filmstrip of every picked item, above the caption field: tap any photo to
  /// open the editor (crop / draw / text / emoji) on **that** one.
  ///
  /// Hidden until something is picked. Videos appear so the strip mirrors the
  /// selection, but carry no pencil and are not tappable — editing one would
  /// need a trimmer, which this editor does not do.
  Widget _editFilmstrip(BuildContext context) {
    return Consumer<DefaultAssetPickerProvider>(
      builder: (context, p, _) {
        final selected = p.selectedAssets;
        if (selected.isEmpty) return const SizedBox.shrink();
        return ValueListenableBuilder<Map<String, String>>(
          valueListenable: edits,
          builder: (context, map, _) {
            return Container(
              height: 52.w,
              margin: EdgeInsets.only(bottom: 8.h),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: selected.length,
                separatorBuilder: (_, _) => SizedBox(width: 8.w),
                itemBuilder: (context, i) {
                  final asset = selected[i];
                  return _filmstripThumb(context, asset, map[asset.id]);
                },
              ),
            );
          },
        );
      },
    );
  }

  /// One filmstrip tile: [asset]'s thumbnail — or its [edited] copy once the
  /// user has drawn on it — with a pencil badge marking it as editable.
  Widget _filmstripThumb(
    BuildContext context,
    AssetEntity asset,
    String? edited,
  ) {
    final isImage = asset.type == AssetType.image;
    return GestureDetector(
      onTap: isImage ? () => _openEditor(context, asset) : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: SizedBox(
              width: 52.w,
              height: 52.w,
              child:
                  edited != null
                      ? Image.file(
                        File(edited),
                        key: ValueKey(edited), // re-read the file after a save
                        fit: BoxFit.cover,
                      )
                      : AssetEntityImage(
                        asset,
                        isOriginal: false,
                        fit: BoxFit.cover,
                      ),
            ),
          ),
          if (isImage)
            PositionedDirectional(
              start: -3.w,
              bottom: -3.h,
              child: Container(
                padding: EdgeInsets.all(3.sp),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: Icon(Icons.edit, size: 11.w, color: Colors.black),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget bottomActionBar(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 8.h),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _editFilmstrip(context),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: caption,
                    minLines: 1,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Add a caption…',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF242424),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 10.h,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24.r),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Consumer<DefaultAssetPickerProvider>(
                  builder: (_, p, _) {
                    final count = p.selectedAssets.length;
                    final enabled = count > 0;
                    return GestureDetector(
                      onTap:
                          enabled
                              ? () => Navigator.maybeOf(
                                context,
                              )?.maybePop(p.selectedAssets)
                              : null,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: EdgeInsets.all(14.sp),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: enabled ? accent : const Color(0xFF3A3A3A),
                            ),
                            child: Icon(
                              Icons.send_rounded,
                              color: enabled ? onAccent : Colors.white38,
                              size: 22.w,
                            ),
                          ),
                          if (enabled)
                            Positioned(
                              right: -2.w,
                              top: -2.h,
                              child: Container(
                                padding: EdgeInsets.all(5.sp),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w700,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
