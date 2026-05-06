// dart format width=80

/// GENERATED CODE - DO NOT MODIFY BY HAND
/// *****************************************************
///  FlutterGen
/// *****************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: deprecated_member_use,directives_ordering,implicit_dynamic_list_literal,unnecessary_import

import 'package:flutter/widgets.dart';

class $AssetsFontsGen {
  const $AssetsFontsGen();

  /// File path: assets/fonts/Poppins_Regular.ttf
  String get poppinsRegular => 'assets/fonts/Poppins_Regular.ttf';

  /// List of all assets
  List<String> get values => [poppinsRegular];
}

class $AssetsIconsGen {
  const $AssetsIconsGen();

  /// File path: assets/icons/add_people.svg
  String get addPeople => 'assets/icons/add_people.svg';

  /// File path: assets/icons/app_logo.svg
  String get appLogo => 'assets/icons/app_logo.svg';

  /// File path: assets/icons/apple_logo.svg
  String get appleLogo => 'assets/icons/apple_logo.svg';

  /// File path: assets/icons/attachment_icon.svg
  String get attachmentIcon => 'assets/icons/attachment_icon.svg';

  /// File path: assets/icons/block_icon.svg
  String get blockIcon => 'assets/icons/block_icon.svg';

  /// File path: assets/icons/camera_icon.svg
  String get cameraIcon => 'assets/icons/camera_icon.svg';

  /// File path: assets/icons/chat.svg
  String get chat => 'assets/icons/chat.svg';

  /// File path: assets/icons/check.svg
  String get check => 'assets/icons/check.svg';

  /// File path: assets/icons/close.svg
  String get close => 'assets/icons/close.svg';

  /// File path: assets/icons/friends.svg
  String get friends => 'assets/icons/friends.svg';

  /// File path: assets/icons/google_logo.svg
  String get googleLogo => 'assets/icons/google_logo.svg';

  /// File path: assets/icons/new_contact.svg
  String get newContact => 'assets/icons/new_contact.svg';

  /// File path: assets/icons/new_group.svg
  String get newGroup => 'assets/icons/new_group.svg';

  /// File path: assets/icons/newchat.svg
  String get newchat => 'assets/icons/newchat.svg';

  /// File path: assets/icons/notification.svg
  String get notification => 'assets/icons/notification.svg';

  /// File path: assets/icons/password_icon.svg
  String get passwordIcon => 'assets/icons/password_icon.svg';

  /// File path: assets/icons/privacy_icon.svg
  String get privacyIcon => 'assets/icons/privacy_icon.svg';

  /// File path: assets/icons/profile.svg
  String get profile => 'assets/icons/profile.svg';

  /// File path: assets/icons/profile_person_icon.svg
  String get profilePersonIcon => 'assets/icons/profile_person_icon.svg';

  /// File path: assets/icons/search_icon.svg
  String get searchIcon => 'assets/icons/search_icon.svg';

  /// File path: assets/icons/send_icon.svg
  String get sendIcon => 'assets/icons/send_icon.svg';

  /// List of all assets
  List<String> get values => [
    addPeople,
    appLogo,
    appleLogo,
    attachmentIcon,
    blockIcon,
    cameraIcon,
    chat,
    check,
    close,
    friends,
    googleLogo,
    newContact,
    newGroup,
    newchat,
    notification,
    passwordIcon,
    privacyIcon,
    profile,
    profilePersonIcon,
    searchIcon,
    sendIcon,
  ];
}

class $AssetsImagesGen {
  const $AssetsImagesGen();

  /// File path: assets/images/no_image.png
  AssetGenImage get noImage =>
      const AssetGenImage('assets/images/no_image.png');

  /// File path: assets/images/on_board_image1.png
  AssetGenImage get onBoardImage1 =>
      const AssetGenImage('assets/images/on_board_image1.png');

  /// File path: assets/images/on_board_image2.png
  AssetGenImage get onBoardImage2 =>
      const AssetGenImage('assets/images/on_board_image2.png');

  /// File path: assets/images/on_board_image3.png
  AssetGenImage get onBoardImage3 =>
      const AssetGenImage('assets/images/on_board_image3.png');

  /// File path: assets/images/onboard_image1.png
  AssetGenImage get onboardImage1 =>
      const AssetGenImage('assets/images/onboard_image1.png');

  /// List of all assets
  List<AssetGenImage> get values => [
    noImage,
    onBoardImage1,
    onBoardImage2,
    onBoardImage3,
    onboardImage1,
  ];
}

class Assets {
  const Assets._();

  static const $AssetsFontsGen fonts = $AssetsFontsGen();
  static const $AssetsIconsGen icons = $AssetsIconsGen();
  static const $AssetsImagesGen images = $AssetsImagesGen();
}

class AssetGenImage {
  const AssetGenImage(
    this._assetName, {
    this.size,
    this.flavors = const {},
    this.animation,
  });

  final String _assetName;

  final Size? size;
  final Set<String> flavors;
  final AssetGenImageAnimation? animation;

  Image image({
    Key? key,
    AssetBundle? bundle,
    ImageFrameBuilder? frameBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    String? semanticLabel,
    bool excludeFromSemantics = false,
    double? scale,
    double? width,
    double? height,
    Color? color,
    Animation<double>? opacity,
    BlendMode? colorBlendMode,
    BoxFit? fit,
    AlignmentGeometry alignment = Alignment.center,
    ImageRepeat repeat = ImageRepeat.noRepeat,
    Rect? centerSlice,
    bool matchTextDirection = false,
    bool gaplessPlayback = true,
    bool isAntiAlias = false,
    String? package,
    FilterQuality filterQuality = FilterQuality.medium,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    return Image.asset(
      _assetName,
      key: key,
      bundle: bundle,
      frameBuilder: frameBuilder,
      errorBuilder: errorBuilder,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      scale: scale,
      width: width,
      height: height,
      color: color,
      opacity: opacity,
      colorBlendMode: colorBlendMode,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: matchTextDirection,
      gaplessPlayback: gaplessPlayback,
      isAntiAlias: isAntiAlias,
      package: package,
      filterQuality: filterQuality,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
  }

  ImageProvider provider({AssetBundle? bundle, String? package}) {
    return AssetImage(_assetName, bundle: bundle, package: package);
  }

  String get path => _assetName;

  String get keyName => _assetName;
}

class AssetGenImageAnimation {
  const AssetGenImageAnimation({
    required this.isAnimation,
    required this.duration,
    required this.frames,
  });

  final bool isAnimation;
  final Duration duration;
  final int frames;
}
