import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/colors.dart';

class ProfileAvatar extends StatelessWidget {
  final String? name;
  final String? avatarUrl;
  final double radius;

  const ProfileAvatar({
    super.key,
    required this.name,
    required this.avatarUrl,
    required this.radius,
  });

  String? _resolveUrl() {
    final raw = avatarUrl?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;

    try {
      return Supabase.instance.client.storage
          .from('profiles')
          .getPublicUrl(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.substring(0, 1).toUpperCase())
        .join();
    final resolvedUrl = _resolveUrl();
    final diameter = radius * 2;

    return ClipOval(
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: resolvedUrl == null
            ? ColoredBox(
                color: AppColors.primary,
                child: Center(
                  child: Text(
                    initials.isNotEmpty ? initials : 'A',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              )
            : Image.network(
                resolvedUrl,
                fit: BoxFit.cover,
                width: diameter,
                height: diameter,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: AppColors.primary,
                  child: Center(
                    child: Text(
                      initials.isNotEmpty ? initials : 'A',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
