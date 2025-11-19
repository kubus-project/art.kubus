import 'package:flutter/material.dart';
import '../services/backend_api_service.dart';
import '../services/user_service.dart';
import 'inline_loading.dart';
import '../screens/user_profile_screen.dart';

class AvatarWidget extends StatefulWidget {
  final String? avatarUrl;
  final String wallet;
  final double radius;
  final bool isLoading;
  final bool allowFabricatedFallback;
  final bool enableProfileNavigation;

  const AvatarWidget({
    super.key,
    this.avatarUrl,
    required this.wallet,
    this.radius = 18,
    this.isLoading = false,
    this.allowFabricatedFallback = true,
    this.enableProfileNavigation = true,
  });

  @override
  State<AvatarWidget> createState() => _AvatarWidgetState();
}

class _AvatarWidgetState extends State<AvatarWidget> {
  String? _effectiveUrl;
  bool _loading = false;
  final BackendApiService _api = BackendApiService();

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    // 1. If explicit URL provided, trust it completely and skip fetch.
    if (widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty) {
      setState(() { _effectiveUrl = _normalizeAvatar(widget.avatarUrl); });
      return;
    }

    // 2. Check cache
    final cached = UserService.getCachedUser(widget.wallet)?.profileImageUrl;
    if (cached != null && cached.isNotEmpty) {
      setState(() { _effectiveUrl = _normalizeAvatar(cached); });
    } 
    
    // 3. Fetch authoritative profile
    // Don't set fabricated URL yet to avoid "Robot -> Real" flash.
    // Show initials/loading state instead.
    
    setState(() { _loading = true; });
    try {
      final u = await UserService.getUserById(widget.wallet);
      if (!mounted) return;
      
      final p = u?.profileImageUrl;
      if (p != null && p.isNotEmpty) {
        setState(() { _effectiveUrl = _normalizeAvatar(p); _loading = false; });
        return;
      }
      
      // 4. If fetch returned nothing, fallback to fabricated if allowed
      if (widget.allowFabricatedFallback) {
        // Only set if we don't have one yet
        if (_effectiveUrl == null || _effectiveUrl!.isEmpty) {
           setState(() { 
             _effectiveUrl = UserService.safeAvatarUrl(widget.wallet); 
             _loading = false; 
           });
        } else {
           setState(() { _loading = false; });
        }
      } else {
        setState(() { _loading = false; });
      }
    } catch (_) {
      if (mounted) {
        // On error, fallback if allowed
          if (widget.allowFabricatedFallback && (_effectiveUrl == null || _effectiveUrl!.isEmpty)) {
            setState(() { _effectiveUrl = UserService.safeAvatarUrl(widget.wallet); });
        }
        setState(() { _loading = false; });
      }
    }
  }

  @override
  void didUpdateWidget(covariant AvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarUrl != widget.avatarUrl || oldWidget.wallet != widget.wallet || oldWidget.allowFabricatedFallback != widget.allowFabricatedFallback) {
      _setup();
    }
  }

  @override
  Widget build(BuildContext context) {
    final effective = _effectiveUrl ?? '';
    final useNetwork = effective.isNotEmpty && (effective.startsWith('http') || effective.startsWith('https'));
    final radius = widget.radius;
    final double size = radius * 2;
    // Boxy shape: Rounded Rectangle with corner radius ~25% of width
    final borderRadius = BorderRadius.circular(radius * 0.5); 

    Widget content;
    if (useNetwork) {
      content = SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Image.network(
            effective,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (ctx, error, stack) {
              final parts = widget.wallet.trim().split(RegExp(r'\s+'));
              final initials = parts.where((p) => p.isNotEmpty).map((p) => p[0]).take(2).join().toUpperCase();
              return Container(
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: borderRadius,
                ),
                alignment: Alignment.center,
                child: Text(initials.isNotEmpty ? initials : 'U', style: TextStyle(fontSize: (radius * 0.7).clamp(10, 14).toDouble(), fontWeight: FontWeight.w600)),
              );
            },
          ),
        ),
      );
    } else {
      final parts = widget.wallet.trim().split(RegExp(r'\s+'));
      final initials = parts.where((p) => p.isNotEmpty).map((p) => p[0]).take(2).join().toUpperCase();
      content = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: borderRadius,
        ),
        alignment: Alignment.center,
        child: Text(initials.isNotEmpty ? initials : 'U', style: TextStyle(fontSize: (radius * 0.7).clamp(10, 14).toDouble(), fontWeight: FontWeight.w600)),
      );
    }

    if (_loading || widget.isLoading) {
      content = Stack(
        alignment: Alignment.center,
        children: [
          content,
          SizedBox(
            width: radius,
            height: radius,
            child: InlineLoading(shape: BoxShape.circle, tileSize: (radius * 0.25).clamp(4.0, 10.0)),
          ),
        ],
      );
    }

    if (widget.enableProfileNavigation) {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfileScreen(userId: widget.wallet),
            ),
          );
        },
        child: content,
      );
    }

    return content;
  }

  String? _normalizeAvatar(String? raw) {
    if (raw == null) return null;
    String candidate = raw.trim();
    if (candidate.isEmpty) return null;

    try {
      if (candidate.startsWith('ipfs://')) {
        final cid = candidate.replaceFirst('ipfs://', '');
        return 'https://ipfs.io/ipfs/$cid';
      }
      if (candidate.startsWith('//')) {
        return 'https:$candidate';
      }
      if (candidate.startsWith('/')) {
        final base = _api.baseUrl.replaceAll(RegExp(r'/$'), '');
        return '$base$candidate';
      }
      if (candidate.contains('api.dicebear.com') && candidate.contains('/svg')) {
        return candidate.replaceAll('/svg', '/png');
      }
    } catch (_) {
      return candidate;
    }
    return candidate;
  }
}
