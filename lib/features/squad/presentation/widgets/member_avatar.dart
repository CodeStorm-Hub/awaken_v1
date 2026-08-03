import 'package:flutter/material.dart';

/// Real avatar image with a graceful initials fallback — shared by the
/// "Live now" cards and leaderboard rows so both a member's own photo (when
/// `profiles.avatar_url` has one) and the no-photo case render identically.
/// Same `cacheWidth`/`cacheHeight`/`errorBuilder`/`loadingBuilder` shape as
/// `ProfileAvatarButton` (`core/theme/expressive_widgets.dart`).
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.displayName,
    required this.avatarUrl,
    required this.size,
    required this.borderRadius,
    required this.background,
    required this.foreground,
  });

  final String displayName;
  final String? avatarUrl;
  final double size;
  final BorderRadius borderRadius;
  final Color background;
  final Color foreground;

  Widget _initials() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, borderRadius: borderRadius),
      child: Center(
        child: Text(
          displayName.isEmpty ? '?' : displayName[0].toUpperCase(),
          style: TextStyle(fontWeight: FontWeight.bold, color: foreground),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl;
    if (url == null || url.isEmpty) return _initials();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * dpr).round(),
        cacheHeight: (size * dpr).round(),
        errorBuilder: (context, error, stackTrace) => _initials(),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _initials(),
      ),
    );
  }
}
