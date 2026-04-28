import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String username;
  final double radius;
  final double? fontSize;
  final bool showOnlineStatus;
  final bool isOnline;

  const UserAvatar({
    super.key,
    required this.photoUrl,
    required this.username,
    this.radius = 20,
    this.fontSize,
    this.showOnlineStatus = false,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;
    
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      if (photoUrl!.startsWith('data:image')) {
        // Handle base64 image
        try {
          final base64String = photoUrl!.split(',').last;
          imageProvider = MemoryImage(base64Decode(base64String));
        } catch (e) {
          // Fallback if base64 decoding fails
          imageProvider = null;
        }
      } else {
        // Handle network image
        imageProvider = NetworkImage(photoUrl!);
      }
    }

    Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.primaryColor,
      backgroundImage: imageProvider,
      child: imageProvider == null
          ? Text(
              username.isNotEmpty ? username[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: fontSize ?? (radius * 0.8),
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            )
          : null,
    );

    if (showOnlineStatus && isOnline) {
      return Stack(
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.6,
              height: radius * 0.6,
              decoration: BoxDecoration(
                color: AppTheme.successColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      );
    }

    return avatar;
  }
}
