import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/config.dart';
import '../providers/presence_provider.dart';
import '../services/user_service.dart';
import '../screens/community/user_profile_screen.dart' as mobile;
import '../screens/desktop/community/desktop_user_profile_screen.dart' as desktop;
import '../utils/wallet_utils.dart';
import '../utils/media_url_resolver.dart';

class AvatarWidget extends StatefulWidget {
  final String? avatarUrl;
  final String wallet;
  final double radius;
  final bool isLoading;
  final bool allowFabricatedFallback;
  final bool enableProfileNavigation;
  final String? heroTag;
  final bool showStatusIndicator;
  final bool? isOnline;
  final Color? statusColor;

  const AvatarWidget({
    super.key,
    this.avatarUrl,
    required this.wallet,
    this.radius = 18,
    this.isLoading = false,
    this.allowFabricatedFallback = false,
    this.enableProfileNavigation = true,
    this.heroTag,
    this.showStatusIndicator = true,
    this.isOnline,
    this.statusColor,
  });

  @override
  State<AvatarWidget> createState() => _AvatarWidgetState();
}

class _AvatarWidgetState extends State<AvatarWidget> with SingleTickerProviderStateMixin {
  String? _effectiveUrl;
  bool _loading = false;
  late AnimationController _shimmerController;
  String? _currentHeroTag;
  String? _presencePrefetchKey;

  @override
  void initState() {
    super.initState();
    _setup();
    _shimmerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prefetchPresenceIfNeeded();
  }

  Future<void> _setup() async {
    final walletId = WalletUtils.normalize(widget.wallet);
    final cacheKey = walletId.isNotEmpty ? walletId : widget.wallet;
    final fallbackSeed = WalletUtils.canonical(widget.wallet);
    // 1. If explicit URL provided, trust it completely and skip fetch.
    if (widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty) {
      setState(() { _effectiveUrl = _normalizeAvatar(widget.avatarUrl); });
      return;
    }

    // 2. Check cache
    final cached = UserService.getCachedUser(cacheKey)?.profileImageUrl;
    if (cached != null && cached.isNotEmpty) {
      setState(() { _effectiveUrl = _normalizeAvatar(cached); });
    } 
    
    // 3. Fetch authoritative profile
    // Skip fetch for placeholder/unknown wallets to avoid unnecessary 404s
    final invalidWalletPlaceholders = ['unknown', 'anonymous', 'n/a', 'none'];
    if (walletId.isEmpty || invalidWalletPlaceholders.contains(walletId)) {
      if (kDebugMode) {
        debugPrint('AvatarWidget: skipping profile fetch for invalid wallet "$walletId"');
      }
      if (widget.allowFabricatedFallback) {
        if (_effectiveUrl == null || _effectiveUrl!.isEmpty) {
          setState(() { _effectiveUrl = UserService.safeAvatarUrl(WalletUtils.canonical(widget.wallet)); });
        }
      }
      return;
    }
    // Don't set fabricated URL yet to avoid "Robot -> Real" flash.
    // Show initials/loading state instead.
    
    setState(() { _loading = true; });
    try {
      final u = await UserService.getUserById(cacheKey);
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
             _effectiveUrl = UserService.safeAvatarUrl(fallbackSeed.isNotEmpty ? fallbackSeed : cacheKey); 
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
            setState(() { _effectiveUrl = UserService.safeAvatarUrl(fallbackSeed.isNotEmpty ? fallbackSeed : cacheKey); });
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
    if (oldWidget.wallet != widget.wallet || oldWidget.showStatusIndicator != widget.showStatusIndicator) {
      _presencePrefetchKey = null;
      _prefetchPresenceIfNeeded();
    }
  }

  @override
  void dispose() {
    try {
      _shimmerController.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effective = _effectiveUrl ?? '';
    final useNetwork = effective.isNotEmpty && (effective.startsWith('http') || effective.startsWith('https'));
    final radius = widget.radius;
    final double size = radius * 2;
    // Boxy shape: Rounded Rectangle with corner radius ~25% of width
    final borderRadius = BorderRadius.circular(radius * 0.15); 

    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = colorScheme.surface;
    Widget content;
    if (useNetwork) {
      content = SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Container(
            color: backgroundColor,
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
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: borderRadius,
                  ),
                  alignment: Alignment.center,
                  child: Text(initials.isNotEmpty ? initials : 'U', style: TextStyle(fontSize: (radius * 0.7).clamp(10, 14).toDouble(), fontWeight: FontWeight.w600)),
                );
              },
            ),
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
          color: colorScheme.surfaceContainerHighest,
          borderRadius: borderRadius,
        ),
        alignment: Alignment.center,
        child: Text(initials.isNotEmpty ? initials : 'U', style: TextStyle(fontSize: (radius * 0.7).clamp(10, 14).toDouble(), fontWeight: FontWeight.w600)),
      );
    }

    if (_loading || widget.isLoading) {
      content = ClipRRect(
        borderRadius: borderRadius,
        child: AnimatedBuilder(
          animation: _shimmerController,
          builder: (context, child) {
            return ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (rect) {
                return LinearGradient(
                  colors: [
                    colorScheme.surfaceContainerHighest,
                    colorScheme.surfaceContainerLow,
                    colorScheme.surfaceContainerHighest,
                  ],
                  stops: const [0.1, 0.5, 0.9],
                  begin: Alignment(-1.0 - 2.0 * _shimmerController.value, 0),
                  end: Alignment(1.0 + 2.0 * _shimmerController.value, 0),
                ).createShader(rect);
              },
              child: child,
            );
          },
          child: content,
        ),
      );
    }

    Widget base = content;
    PresenceProvider? presenceProvider;
    try {
      presenceProvider = Provider.of<PresenceProvider>(context);
    } catch (_) {
      presenceProvider = null;
    }
    final presence = presenceProvider?.presenceForWallet(widget.wallet);
    final bool presenceVisible = presence?.visible == true;
    final bool? presenceOnline = presence?.isOnline;

    final bool? effectiveOnline = presence != null ? presenceOnline : widget.isOnline;
    final bool shouldShowPresence = AppConfig.isFeatureEnabled('presence') && widget.showStatusIndicator && (presence == null ? true : presenceVisible) && effectiveOnline != null;

    if (shouldShowPresence) {
      final indicatorSize = (radius * 0.75).clamp(14.0, 18.0).toDouble();
      final indicatorColor = widget.statusColor ?? (effectiveOnline == true ? colorScheme.tertiary : colorScheme.outlineVariant);
      base = Stack(
        clipBehavior: Clip.none,
        children: [
          content,
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              key: const ValueKey('avatar_presence_indicator'),
              width: indicatorSize,
              height: indicatorSize,
              decoration: BoxDecoration(
                color: indicatorColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Wrap content in Hero when a tag is present (temporary or provided)
    final tag = widget.heroTag ?? _currentHeroTag;
    Widget wrapped = base;
    if (tag != null && tag.isNotEmpty) {
      wrapped = Hero(tag: tag, child: base);
    }

    if (widget.enableProfileNavigation) {
      return GestureDetector(
        onTap: () {
          // Generate unique hero tag for this navigation
          final newTag = 'avatar_${WalletUtils.normalize(widget.wallet)}_${DateTime.now().microsecondsSinceEpoch}';
          setState(() { _currentHeroTag = newTag; });
          
          // Detect if we're on desktop and route to desktop profile screen
          final screenWidth = MediaQuery.of(context).size.width;
          final isDesktop = screenWidth >= 900;
          
          final profileScreen = isDesktop
              ? desktop.UserProfileScreen(userId: widget.wallet, heroTag: newTag)
              : mobile.UserProfileScreen(userId: widget.wallet, heroTag: newTag);
          
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => profileScreen),
          ).then((_) {
            // clear temporary hero tag after return
            if (mounted) setState(() { _currentHeroTag = null; });
          });
        },
        child: wrapped,
      );
    }

    return wrapped;
  }

  void _prefetchPresenceIfNeeded() {
    if (!AppConfig.isFeatureEnabled('presence')) return;
    if (!widget.showStatusIndicator) return;
    final wallet = widget.wallet.trim();
    if (wallet.isEmpty) return;

    final normalized = WalletUtils.normalize(wallet).toLowerCase();
    const invalid = {'unknown', 'anonymous', 'n/a', 'none'};
    if (normalized.isEmpty || invalid.contains(normalized)) return;

    PresenceProvider? provider;
    try {
      provider = Provider.of<PresenceProvider>(context, listen: false);
    } catch (_) {
      provider = null;
    }
    if (provider == null) return;

    if (_presencePrefetchKey == normalized) return;
    _presencePrefetchKey = normalized;
    provider.prefetch([wallet]);
  }

  String? _normalizeAvatar(String? raw) {
    if (raw == null) return null;
    String candidate = raw.trim();
    if (candidate.isEmpty) return null;

    try {
      if (UserService.isPlaceholderAvatarUrl(candidate)) return null;

      final lower = candidate.toLowerCase();
      if (lower.contains('dicebear') &&
          (lower.contains('/svg') || lower.endsWith('.svg') || lower.contains('format=svg'))) {
        candidate = candidate.replaceAll('/svg', '/png').replaceAll('.svg', '.png');
      }

      if (candidate.startsWith('//')) {
        candidate = 'https:$candidate';
      }
    } catch (_) {
      return candidate;
    }

    return MediaUrlResolver.resolve(candidate) ?? candidate;
  }
}
