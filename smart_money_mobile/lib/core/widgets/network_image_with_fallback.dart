import 'package:flutter/material.dart';

import '../network/api_config.dart';
import '../theme/sm_colors.dart';

/// Renders a remote image and gracefully degrades to an icon placeholder.
///
/// Guarantees the app never shows a broken-image widget: a null / empty URL
/// short-circuits to the placeholder, and any decode/network failure is caught
/// by [Image.network]'s `errorBuilder`. Relative URLs (e.g. `/media/x.png`) are
/// resolved against [ApiConfig.baseUrl]; absolute `http(s)` URLs are used as-is.
class NetworkImageWithFallback extends StatelessWidget {
  const NetworkImageWithFallback({
    super.key,
    required this.url,
    this.fallbackIcon = Icons.image_outlined,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.backgroundColor,
    this.iconColor,
    this.iconSize,
    this.opacity,
  });

  final String? url;
  final IconData fallbackIcon;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Color? backgroundColor;
  final Color? iconColor;
  final double? iconSize;

  /// Paint opacity applied by [Image] itself. Prefer this over wrapping the
  /// widget in an [Opacity], which forces a `saveLayer` on every frame.
  final double? opacity;

  String? get _resolvedUrl {
    final raw = url?.trim() ?? '';
    if (raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final base = ApiConfig.baseUrl;
    return raw.startsWith('/') ? '$base$raw' : '$base/$raw';
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolvedUrl;
    final colors = SmColors.of(context);

    if (resolved == null) {
      return _buildFallback(colors);
    }

    return Image.network(
      resolved,
      fit: fit,
      width: width,
      height: height,
      opacity: opacity == null ? null : AlwaysStoppedAnimation<double>(opacity!),
      filterQuality: FilterQuality.medium,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _buildPlaceholder(
          colors,
          Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary,
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => _buildFallback(colors),
    );
  }

  Widget _buildFallback(SmColors colors) {
    return _buildPlaceholder(
      colors,
      Center(
        child: Icon(
          fallbackIcon,
          color: iconColor ?? colors.textMuted,
          size: iconSize ?? 26,
        ),
      ),
    );
  }

  Widget _buildPlaceholder(SmColors colors, Widget child) {
    return Container(
      width: width,
      height: height,
      color: backgroundColor ?? colors.surfaceHover,
      child: child,
    );
  }
}
