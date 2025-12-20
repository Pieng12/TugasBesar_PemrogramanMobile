import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Uniform Servify logo widget with PNG/SVG fallback handling.
class ServifyLogo extends StatelessWidget {
  const ServifyLogo({
    super.key,
    this.size = 48,
    this.variant = ServifyLogoVariant.png,
    this.fit = BoxFit.contain,
    this.padding,
  });

  final double size;
  final ServifyLogoVariant variant;
  final BoxFit fit;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final child = variant == ServifyLogoVariant.svg
        ? _buildSvgLogo()
        : _buildPngLogo();

    if (padding != null) {
      return Padding(
        padding: padding!,
        child: child,
      );
    }
    return child;
  }

  Widget _buildPngLogo() {
    return Image.asset(
      'assets/logo/Servify-nobg.png',
      width: size,
      height: size,
      fit: fit,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
      errorBuilder: (context, error, stackTrace) {
        return _buildSvgLogo();
      },
    );
  }

  Widget _buildSvgLogo() {
    return SvgPicture.asset(
      'assets/logo/vectorized.svg',
      width: size,
      height: size,
      fit: fit,
      placeholderBuilder: (context) => SizedBox(
        width: size,
        height: size,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

enum ServifyLogoVariant { png, svg }












