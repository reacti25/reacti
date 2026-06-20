import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A circular avatar that shows a photo when available and falls back to the
/// person's initials on a stable, per-name colour otherwise.
///
/// Renders [url] as a cropped circular network image. When [url] is empty, or
/// the image is still loading or fails to load, a coloured circle with the
/// initials derived from [firstName]/[lastName] is shown instead — two initials
/// when both names are present, one when only a single name is, and a neutral
/// `?` when neither is. The background colour is picked deterministically from
/// the name, so a given person keeps the same colour across rebuilds and across
/// the 1:1 and group chat screens.
class AvatarCircle extends StatelessWidget {
  /// Avatar image URL; when null/empty the [initials] fallback is shown.
  final String? url;

  /// The person's first name — first initial and the colour seed.
  final String? firstName;

  /// The person's last name — second initial.
  final String? lastName;

  /// Diameter of the circle, in logical pixels.
  final double size;

  /// Palette the per-name background colour is chosen from. Mid-tone colours
  /// so the white initials stay legible on every one.
  static const List<Color> _palette = [
    Color(0xFF1ABC9C),
    Color(0xFF3498DB),
    Color(0xFF9B59B6),
    Color(0xFFE67E22),
    Color(0xFFE74C3C),
    Color(0xFF16A085),
    Color(0xFF2980B9),
    Color(0xFF8E44AD),
    Color(0xFFD35400),
    Color(0xFFC0392B),
  ];

  /// Creates an [AvatarCircle] of the given [size].
  const AvatarCircle({
    super.key,
    required this.size,
    this.url,
    this.firstName,
    this.lastName,
  });

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.trim().isNotEmpty;
    if (!hasUrl) {
      return _initialsCircle();
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // Initials stand in while the photo loads and if it fails — never a
        // blank or broken-image gap.
        placeholder: (context, _) => _initialsCircle(),
        errorWidget: (context, _, _) => _initialsCircle(),
      ),
    );
  }

  /// The coloured initials fallback circle.
  Widget _initialsCircle() {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _backgroundColor(),
        shape: BoxShape.circle,
      ),
      child: Text(
        _initials(),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Up to two uppercase initials, or `?` when no name is available.
  String _initials() {
    final first = (firstName ?? '').trim();
    final last = (lastName ?? '').trim();
    final a = first.isNotEmpty ? first[0] : '';
    final b = last.isNotEmpty ? last[0] : '';
    final initials = (a + b).toUpperCase();
    return initials.isNotEmpty ? initials : '?';
  }

  /// A palette colour seeded by the name, so the same name always maps to the
  /// same colour. A plain code-unit sum keeps it deterministic across runs
  /// (unlike [String.hashCode], which can be seed-randomised).
  Color _backgroundColor() {
    final key = '${firstName ?? ''} ${lastName ?? ''}'.trim();
    if (key.isEmpty) {
      return _palette.first;
    }
    var sum = 0;
    for (final unit in key.codeUnits) {
      sum += unit;
    }
    return _palette[sum % _palette.length];
  }
}
