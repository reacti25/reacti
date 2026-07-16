import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

/// Result of the WhatsApp-style picker: the chosen assets and the one caption
/// typed inline in the picker's bottom bar.
class WhatsAppPickResult {
  const WhatsAppPickResult(this.assets, this.caption);

  final List<AssetEntity> assets;
  final String caption;
}

/// Opens a WhatsApp-style media picker: a dense multi-select grid with an
/// **inline "Add a caption…" + send bar** at the bottom (no separate confirm
/// button and no separate review page for the common case).
///
/// Built on `wechat_assets_picker` by subclassing its default delegate — so it
/// reuses the package's album/permission/paging engine and only restyles the
/// bottom bar. Returns null when the user backs out without sending.
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

  final assets = await AssetPicker.pickAssetsWithDelegate(
    context,
    delegate: delegate,
    permissionRequestOption: permissionOption,
  );
  final text = caption.text.trim();
  caption.dispose();
  if (assets == null || assets.isEmpty) return null;
  return WhatsAppPickResult(assets, text);
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

  @override
  Widget bottomActionBar(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 8.h),
      child: SafeArea(
        top: false,
        child: Row(
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
      ),
    );
  }
}
