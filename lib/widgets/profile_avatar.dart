import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/api_config.dart';

/// Widget untuk menampilkan foto profil user dengan fallback ke icon default
class ProfileAvatar extends StatelessWidget {
  final String? profileImagePath;
  final double radius;
  final Color? backgroundColor;
  final Color? iconColor;
  final String? name; // Untuk fallback initial jika tidak ada foto
  final BoxDecoration? decoration;

  const ProfileAvatar({
    super.key,
    this.profileImagePath,
    this.radius = 25,
    this.backgroundColor,
    this.iconColor,
    this.name,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = profileImagePath != null && profileImagePath!.isNotEmpty
        ? ApiConfig.getImageUrl(profileImagePath)
        : null;

    final bgColor = backgroundColor ?? Colors.grey[300]!;
    final iconClr = iconColor ?? Colors.grey[600]!;

    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: imageUrl != null && imageUrl.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: radius * 2,
                  height: radius * 2,
                  color: bgColor,
                  child: Center(
                    child: SizedBox(
                      width: radius * 0.6,
                      height: radius * 0.6,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(iconClr),
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => _buildFallback(bgColor, iconClr),
              ),
            )
          : _buildFallback(bgColor, iconClr),
    );
  }

  Widget _buildFallback(Color bgColor, Color iconClr) {
    // Jika ada name, tampilkan initial
    if (name != null && name!.isNotEmpty) {
      return Text(
        name![0].toUpperCase(),
        style: TextStyle(
          color: iconClr,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      );
    }
    
    // Jika tidak ada name, tampilkan icon
    return Icon(
      Icons.person_rounded,
      size: radius * 1.2,
      color: iconClr,
    );
  }
}





