import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'avatar_circle.dart';
import 'custom_network_image.dart';

/// A circular group avatar: the group's photo when one is set, otherwise a
/// neutral multi-person icon.
///
/// A group with no uploaded picture comes back either empty or pointing at the
/// backend default placeholder (`default/default_image.jpg`). Those must not be
/// drawn as a photo — [AvatarCircle.isRealPhotoUrl] tells a real photo apart
/// from those markers, so we can show [Icons.group] instead of a blank or
/// broken-image circle. Used for group rows in the chat list (1:1 rows keep
/// their own person fallback).
class GroupAvatar extends StatelessWidget {
  /// The group image URL; null/empty or a default-placeholder marker shows the
  /// people icon instead.
  final String? url;

  /// Diameter of the circle, in logical pixels.
  final double size;

  /// Creates a [GroupAvatar] of the given [size].
  const GroupAvatar({super.key, required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    if (AvatarCircle.isRealPhotoUrl(url)) {
      return ClipOval(
        child: CustomNetworkImage(width: size, height: size, urls: url!),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.reacti.avatarPlaceholderBg,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.group,
        color: context.reacti.textSecondary,
        size: size * 0.55,
      ),
    );
  }
}
