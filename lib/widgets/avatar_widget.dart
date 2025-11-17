import 'package:flutter/material.dart';
import '../services/user_service.dart';

class AvatarWidget extends StatelessWidget {
  final String? avatarUrl;
  final String wallet;
  final double radius;

  const AvatarWidget({super.key, this.avatarUrl, required this.wallet, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    final effective = (avatarUrl != null && avatarUrl!.isNotEmpty) ? avatarUrl! : UserService.safeAvatarUrl(wallet);
    final useNetwork = effective.isNotEmpty && (effective.startsWith('http') || effective.startsWith('https'));
    if (useNetwork) {
      return SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: ClipOval(
          child: Image.network(
            effective,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (ctx, error, stack) {
              final parts = wallet.trim().split(RegExp(r'\\s+'));
              final initials = parts.where((p) => p.isNotEmpty).map((p) => p[0]).take(2).join().toUpperCase();
              return Container(
                color: Colors.grey[300],
                alignment: Alignment.center,
                child: Text(initials.isNotEmpty ? initials : 'U', style: TextStyle(fontSize: (radius * 0.7).clamp(10, 14).toDouble(), fontWeight: FontWeight.w600)),
              );
            },
          ),
        ),
      );
    }
    final parts = wallet.trim().split(RegExp(r'\\s+'));
    final initials = parts.where((p) => p.isNotEmpty).map((p) => p[0]).take(2).join().toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[300],
      child: Text(initials.isNotEmpty ? initials : 'U', style: TextStyle(fontSize: (radius * 0.7).clamp(10, 14).toDouble(), fontWeight: FontWeight.w600)),
    );
  }
}
