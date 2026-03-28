import 'package:flutter/material.dart';
import '../../utils/design_tokens.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as path;
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../providers/profile_provider.dart';
import '../../providers/dao_provider.dart';
import '../../services/backend_api_service.dart';
import '../../models/user.dart';
import '../../models/dao.dart';
import '../../services/event_bus.dart';
import '../../providers/themeprovider.dart';
import '../../widgets/inline_loading.dart';
import '../../utils/media_url_resolver.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:art_kubus/widgets/common/keyboard_inset_padding.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key, this.isOnboarding = false});

  final bool isOnboarding;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _displayNameController;
  late TextEditingController _bioController;
  late TextEditingController _twitterController;
  late TextEditingController _instagramController;
  late TextEditingController _websiteController;

  // Artist-specific fields
  late TextEditingController _specialtyController;
  late TextEditingController _yearsActiveController;

  String? _avatarUrl;
  String? _coverImageUrl;
  bool _isLoading = false;
  Uint8List? _localAvatarBytes;
  Uint8List? _localCoverBytes;
  final ImagePicker _picker = ImagePicker();
  VoidCallback? _profileListener;
  ProfileProvider? _profileProvider;

  // Privacy settings
  bool _privateProfile = false;
  bool _showActivityStatus = true;
  bool _shareLastVisitedLocation = false;
  bool _showCollection = true;
  bool _allowMessages = true;

  // Role flags
  bool _isArtist = false;
  bool _isInstitution = false;

  @override
  void initState() {
    super.initState();
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    _profileProvider = profileProvider;
    DAOProvider? daoProvider;
    try {
      daoProvider = Provider.of<DAOProvider>(context, listen: false);
    } catch (_) {
      daoProvider = null;
    }
    final profile = profileProvider.currentUser;

    // Show username without any leading '@' in the edit field for a cleaner UX.
    final initialUsername =
        (profile?.username ?? '').toString().replaceFirst(RegExp(r'^@+'), '');
    _usernameController = TextEditingController(text: initialUsername);
    _displayNameController =
        TextEditingController(text: profile?.displayName ?? '');
    _bioController = TextEditingController(text: profile?.bio ?? '');
    // Avoid null map index when social is null
    final social = profile?.social ?? <String, String>{};
    _twitterController = TextEditingController(text: social['twitter'] ?? '');
    _instagramController =
        TextEditingController(text: social['instagram'] ?? '');
    _websiteController = TextEditingController(text: social['website'] ?? '');
    _avatarUrl = profile?.avatar;
    _coverImageUrl = _normalizeMediaUrl(profile?.coverImage);

    // Artist-specific fields
    final artistInfo = profile?.artistInfo;
    _specialtyController = TextEditingController(
      text: artistInfo?.specialty.join(', ') ?? '',
    );
    _yearsActiveController = TextEditingController(
      text: artistInfo?.yearsActive.toString() ?? '0',
    );

    // Privacy settings
    final prefs = profile?.preferences ?? profileProvider.preferences;
    _privateProfile = prefs.privacy.toLowerCase() == 'private';
    _showActivityStatus = prefs.showActivityStatus;
    _shareLastVisitedLocation = prefs.shareLastVisitedLocation;
    _showCollection = prefs.showCollection;
    _allowMessages = prefs.allowMessages;

    // Determine role flags
    _isArtist = profile?.isArtist ?? false;
    _isInstitution = profile?.isInstitution ?? false;

    // Check DAO review for approved artist/institution status
    final walletAddress = profile?.walletAddress ?? '';
    if (walletAddress.isNotEmpty && daoProvider != null) {
      final daoReview = daoProvider.findReviewForWallet(walletAddress);
      if (daoReview != null && daoReview.isApproved) {
        if (daoReview.isArtistApplication) _isArtist = true;
        if (daoReview.isInstitutionApplication) _isInstitution = true;
      }
    }

    // Listen to profile provider changes so avatar updates immediately when provider updates
    _profileListener = () {
      final p = profileProvider.currentUser;
      if (!mounted) return;
      setState(() {
        _avatarUrl = p?.avatar;
        _coverImageUrl = _normalizeMediaUrl(p?.coverImage);
      });
    };
    profileProvider.addListener(_profileListener!);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _bioController.dispose();
    _twitterController.dispose();
    _instagramController.dispose();
    _websiteController.dispose();
    _specialtyController.dispose();
    _yearsActiveController.dispose();
    if (_profileListener != null) {
      _profileProvider?.removeListener(_profileListener!);
      _profileListener = null;
    }
    _profileProvider = null;
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        // Read bytes and show local preview immediately (works for gallery and PC)
        final bytes = await image.readAsBytes();
        if (!mounted) return;
        setState(() {
          _localAvatarBytes = bytes;
          _isLoading = true;
        });

        try {
          final profileProvider =
              Provider.of<ProfileProvider>(context, listen: false);
          final wallet = profileProvider.currentUser?.walletAddress ?? '';

          if (wallet.isEmpty) {
            setState(() => _isLoading = false);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showKubusSnackBar(
              SnackBar(
                content: Text(l10n.profileEditNoWalletUploadAvatarToast),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
            return;
          }

          // Ensure profile exists and obtain JWT for authenticated upload
          await profileProvider.saveProfile(walletAddress: wallet);

          // Upload avatar to backend using bytes (handles content:// URIs on Android)
          final fileName =
              (image.name.isNotEmpty) ? image.name : path.basename(image.path);
          final uploadedUrl = await profileProvider.uploadAvatarBytes(
            fileBytes: bytes,
            fileName: fileName,
            walletAddress: wallet,
            mimeType: image.mimeType,
          );

          // Immediately save the avatar URL to the profile on the backend so it persists
          final saved = await profileProvider.saveProfile(
            walletAddress: wallet,
            avatar: uploadedUrl,
          );

          setState(() {
            _avatarUrl = uploadedUrl;
            // Keep local preview cleared since backend URL is now available
            _localAvatarBytes = null;
            _isLoading = false;
          });

          // Show resolved URL with actions: copy and open in browser
          if (!mounted) return;
          final uri = Uri.tryParse(uploadedUrl);
          ScaffoldMessenger.of(context).showKubusSnackBar(
            SnackBar(
              duration: const Duration(seconds: 6),
              content: Row(
                children: [
                  Expanded(
                    child: Text(
                      uploadedUrl,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20, color: Colors.white),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: uploadedUrl));
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showKubusSnackBar(
                        SnackBar(
                          content: Text(
                              l10n.profileEditAvatarCopiedToClipboardToast),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
              action: uri != null
                  ? SnackBarAction(
                      label: l10n.commonOpen,
                      onPressed: () async {
                        try {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        } catch (_) {}
                      },
                    )
                  : null,
            ),
          );

          if (!mounted) return;
          ScaffoldMessenger.of(context).showKubusSnackBar(
            SnackBar(
              content: Text(
                saved
                    ? l10n.profileEditAvatarUploadedSavedToast
                    : l10n.profileEditAvatarUploadedLocalToast,
              ),
              backgroundColor: saved
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.secondary,
              duration: const Duration(seconds: 2),
            ),
          );
        } catch (e) {
          setState(() => _isLoading = false);
          if (!mounted) return;
          final profileProvider =
              Provider.of<ProfileProvider>(context, listen: false);
          // Show snackbar
          ScaffoldMessenger.of(context).showKubusSnackBar(
            SnackBar(
              content:
                  Text(l10n.profileEditAvatarUploadFailedToast(e.toString())),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );

          // If debug info is available, show detailed dialog with raw server response
          final debug = profileProvider.lastUploadDebug;
          if (debug != null) {
            final pretty = const JsonEncoder.withIndent('  ').convert(debug);
            showKubusDialog<void>(
              context: context,
              builder: (context) => KubusAlertDialog(
                title: Text(l10n.profileEditUploadDebugInfoTitle),
                content: SingleChildScrollView(
                  child: SelectableText(pretty),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.commonClose),
                  ),
                  TextButton(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      await Clipboard.setData(ClipboardData(text: pretty));
                      if (!mounted) return;
                      navigator.pop();
                      messenger.showKubusSnackBar(
                        SnackBar(
                            content: Text(
                                l10n.profileEditUploadDebugInfoCopiedToast)),
                      );
                    },
                    child: Text(l10n.commonCopy),
                  ),
                ],
              ),
            );
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(l10n.profileEditPickImageFailedToast(e.toString())),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _pickCoverImage() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 90,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        if (!mounted) return;
        setState(() {
          _localCoverBytes = bytes;
          _isLoading = true;
        });

        try {
          final profileProvider =
              Provider.of<ProfileProvider>(context, listen: false);
          final wallet = profileProvider.currentUser?.walletAddress ?? '';

          if (wallet.isEmpty) {
            if (mounted) setState(() => _isLoading = false);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showKubusSnackBar(
              SnackBar(
                content: Text(l10n.profileEditNoWalletUploadCoverToast),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
            return;
          }

          // Upload cover image to backend
          final fileName =
              (image.name.isNotEmpty) ? image.name : path.basename(image.path);
          final api = BackendApiService();
          final result = await api.uploadFile(
            fileBytes: bytes,
            fileName: fileName,
            fileType: 'cover',
            metadata: {'uploadFolder': 'profiles/cover'},
            walletAddress: wallet,
          );

          // Prefer a backend-stable ref for persistence (covers must be saved as
          // `/uploads/...`/`/profiles/...` paths; absolute URLs get rejected and
          // can clear the cover on save).
          final uploadedRef = (result['uploadedUrl']?.toString() ??
                  result['data']?['relativeUrl']?.toString() ??
                  result['data']?['relative_url']?.toString() ??
                  result['data']?['url']?.toString() ??
                  result['url']?.toString() ??
                  '')
              .trim();

          if (uploadedRef.isEmpty) {
            throw Exception('Failed to get uploaded cover ref');
          }

          final displayUrl = _normalizeMediaUrl(uploadedRef) ?? uploadedRef;

          // Save cover ref to profile (persist raw, not resolved)
          final saved = await profileProvider.saveProfile(
            walletAddress: wallet,
            coverImage: uploadedRef,
          );

          if (mounted) {
            setState(() {
              _coverImageUrl = displayUrl;
              _localCoverBytes = null;
              _isLoading = false;
            });
          }

          if (!mounted) return;
          ScaffoldMessenger.of(context).showKubusSnackBar(
            SnackBar(
              content: Text(
                saved
                    ? l10n.profileEditCoverUploadedSavedToast
                    : l10n.profileEditCoverUploadedLocalToast,
              ),
              backgroundColor: saved
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.secondary,
              duration: const Duration(seconds: 2),
            ),
          );
        } catch (e) {
          if (mounted) setState(() => _isLoading = false);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showKubusSnackBar(
            SnackBar(
              content:
                  Text(l10n.profileEditCoverUploadFailedToast(e.toString())),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(l10n.profileEditPickImageFailedToast(e.toString())),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);

    try {
      final profileProvider =
          Provider.of<ProfileProvider>(context, listen: false);
      final wallet = profileProvider.currentUser?.walletAddress;

      if (wallet == null) {
        throw Exception('No wallet connected');
      }

      // Save privacy settings first
      await profileProvider.updatePreferences(
        privateProfile: _privateProfile,
        showActivityStatus: _showActivityStatus,
        shareLastVisitedLocation: _shareLastVisitedLocation,
        showCollection: _showCollection,
        allowMessages: _allowMessages,
      );

      final success = await profileProvider.saveProfile(
        walletAddress: wallet,
        username: _usernameController.text.trim(),
        displayName: _displayNameController.text.trim(),
        bio: _bioController.text.trim(),
        avatar: _avatarUrl,
        coverImage: _coverImageUrl,
        social: {
          'twitter': _twitterController.text.trim(),
          'instagram': _instagramController.text.trim(),
          'website': _websiteController.text.trim(),
        },
        fieldOfWork: _specialtyController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(growable: false),
        yearsActive: int.tryParse(_yearsActiveController.text.trim()) ?? 0,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(
            content: Text(l10n.profileEditProfileUpdatedToast),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        // Also update ChatProvider and UserService caches to ensure other screens
        // (e.g., MessagesScreen) show the updated avatar/displayName immediately.
        try {
          final uprof = profileProvider.currentUser;
          if (uprof != null) {
            final User updatedUser = User(
              id: uprof.walletAddress,
              name: uprof.displayName,
              username: uprof.username,
              bio: uprof.bio,
              profileImageUrl: uprof.avatar,
              coverImageUrl: _normalizeMediaUrl(uprof.coverImage),
              followersCount: uprof.stats?.followersCount ?? 0,
              followingCount: uprof.stats?.followingCount ?? 0,
              postsCount: uprof.stats?.artworksCreated ?? 0,
              isFollowing: false,
              isVerified: false,
              joinedDate: uprof.createdAt.toIso8601String(),
              achievementProgress: [],
            );
            try {
              EventBus().emitProfileUpdated(updatedUser);
            } catch (_) {}
          }
        } catch (_) {}

        // If this is onboarding, redirect to main screen after saving
        if (widget.isOnboarding) {
          Navigator.of(context).pushReplacementNamed('/main');
        } else {
          Navigator.pop(context, true);
        }
      } else {
        throw Exception(profileProvider.error ?? l10n.commonActionFailedToast);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(l10n.profileEditErrorToast(e.toString())),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildAvatarWidget(String url, ThemeProvider themeProvider) {
    // If we have a local picked image, show it immediately
    if (_localAvatarBytes != null) {
      return Image.memory(
        _localAvatarBytes!,
        fit: BoxFit.cover,
        width: 120,
        height: 120,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.person,
            size: 60,
            color: themeProvider.accentColor,
          );
        },
      );
    }
    // Ensure we use raster images; for DiceBear URLs, prefer the internal proxy so we don't hit the external CDN directly
    String displayUrl = url;
    try {
      final lower = url.toLowerCase();
      if (lower.contains('dicebear')) {
        // Build proxy path `/api/avatar/<seed>?style=<style>&format=png`
        String seed = '';
        String style = 'identicon';
        try {
          final u = Uri.parse(url);
          if (u.queryParameters.containsKey('seed')) {
            seed = u.queryParameters['seed']!;
            final segs = u.pathSegments;
            if (segs.isNotEmpty) {
              style = segs.lastWhere((s) => s.isNotEmpty,
                  orElse: () => 'identicon');
            }
          } else {
            final last = u.pathSegments.isNotEmpty ? u.pathSegments.last : '';
            seed = last.replaceAll('.svg', '');
            if (u.pathSegments.length >= 2) {
              style = u.pathSegments[u.pathSegments.length - 2];
            }
          }
        } catch (_) {
          final p = url.split('/').last;
          seed = p.split('?').first.replaceAll('.svg', '');
        }
        final base = BackendApiService().baseUrl.replaceAll(RegExp(r'/$'), '');
        displayUrl =
            '$base/api/avatar/${Uri.encodeComponent(seed)}?style=$style&format=png&raw=true';
      } else if (lower.endsWith('.svg') || lower.contains('.svg?')) {
        displayUrl =
            url.replaceAll(RegExp(r'\.svg', caseSensitive: false), '.png');
      }
    } catch (_) {
      displayUrl = url;
    }

    return Image.network(
      displayUrl,
      fit: BoxFit.cover,
      width: 120,
      height: 120,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.person,
          size: 60,
          color: themeProvider.accentColor,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.profileEditTitle,
          style: KubusTypography.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          if (_isLoading)
            Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: InlineLoading(
                      expand: true, shape: BoxShape.circle, tileSize: 4.0),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: Text(
                l10n.commonSave,
                style: KubusTypography.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: themeProvider.accentColor,
                ),
              ),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return KeyboardInsetPadding(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(KubusSpacing.lg),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cover Image section
                      _buildSectionHeader(
                          l10n.commonCoverImage, Icons.panorama),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _pickCoverImage,
                        child: Container(
                          width: double.infinity,
                          height: 150,
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: themeProvider.accentColor
                                  .withValues(alpha: 0.3),
                              width: 2,
                              style: BorderStyle.solid,
                            ),
                            image: _localCoverBytes != null
                                ? DecorationImage(
                                    image: MemoryImage(_localCoverBytes!),
                                    fit: BoxFit.cover,
                                  )
                                : _coverImageUrl != null &&
                                        _coverImageUrl!.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(_coverImageUrl!),
                                        fit: BoxFit.cover,
                                        onError: (error, stackTrace) {
                                          // Swallow image load errors (e.g., 404) so Flutter web
                                          // doesn't surface them as unhandled zone errors.
                                        },
                                      )
                                    : null,
                          ),
                          child: (_localCoverBytes == null &&
                                  (_coverImageUrl == null ||
                                      _coverImageUrl!.isEmpty))
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 40,
                                      color: themeProvider.accentColor
                                          .withValues(alpha: 0.6),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      l10n.profileEditCoverImageTapToAdd,
                                      style: KubusTypography.inter(
                                        fontSize: 14,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                )
                              : Stack(
                                  children: [
                                    Positioned(
                                      bottom: 12,
                                      right: 12,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.edit,
                                                color: Colors.white, size: 16),
                                            const SizedBox(width: 4),
                                            Text(
                                              l10n.commonChange,
                                              style: KubusTypography.inter(
                                                fontSize: 12,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Avatar section
                      _buildSectionHeader(
                        l10n.profileEditProfilePictureTitle,
                        Icons.account_circle,
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _pickAvatar,
                              child: Stack(
                                children: [
                                  Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: themeProvider.accentColor,
                                        width: 3,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: _avatarUrl != null &&
                                              _avatarUrl!.isNotEmpty
                                          ? _buildAvatarWidget(
                                              _avatarUrl!, themeProvider)
                                          : Icon(
                                              Icons.person,
                                              size: 60,
                                              color: themeProvider.accentColor,
                                            ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: themeProvider.accentColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surface,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n.profileEditAvatarTapToChange,
                              style: KubusTypography.inter(
                                fontSize: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Basic Info Section
                      _buildSectionHeader(
                        l10n.profileEditBasicInformationTitle,
                        Icons.person_outline,
                      ),
                      const SizedBox(height: 16),

                      // Username
                      Text(
                        l10n.profileEditUsernameLabel,
                        style: KubusTypography.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          hintText: l10n.profileEditUsernameHint,
                          prefixIcon: const Icon(Icons.alternate_email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor:
                              Theme.of(context).colorScheme.primaryContainer,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.profileEditUsernameRequiredError;
                          }
                          if (value.trim().length < 3) {
                            return l10n.profileEditUsernameMinLengthError;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Display Name
                      Text(
                        l10n.profileEditDisplayNameLabel,
                        style: KubusTypography.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _displayNameController,
                        decoration: InputDecoration(
                          hintText: l10n.profileEditDisplayNameHint,
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor:
                              Theme.of(context).colorScheme.primaryContainer,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.profileEditDisplayNameRequiredError;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Bio
                      Text(
                        l10n.profileEditBioLabel,
                        style: KubusTypography.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _bioController,
                        maxLines: 4,
                        maxLength: 200,
                        decoration: InputDecoration(
                          hintText: l10n.profileEditBioHint,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Social Links Section
                      Text(
                        l10n.profileEditSocialLinksTitle,
                        style: KubusTypography.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Twitter
                      TextFormField(
                        controller: _twitterController,
                        decoration: InputDecoration(
                          hintText: l10n.profileEditSocialHandleHint,
                          labelText: l10n.profileEditSocialTwitterLabel,
                          prefixIcon: const Icon(Icons.alternate_email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor:
                              Theme.of(context).colorScheme.primaryContainer,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Instagram
                      TextFormField(
                        controller: _instagramController,
                        decoration: InputDecoration(
                          hintText: l10n.profileEditSocialHandleHint,
                          labelText: l10n.profileEditSocialInstagramLabel,
                          prefixIcon: const Icon(Icons.camera_alt),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor:
                              Theme.of(context).colorScheme.primaryContainer,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Website
                      TextFormField(
                        controller: _websiteController,
                        decoration: InputDecoration(
                          hintText: l10n.profileEditSocialWebsiteHint,
                          labelText: l10n.profileEditSocialWebsiteLabel,
                          prefixIcon: const Icon(Icons.language),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor:
                              Theme.of(context).colorScheme.primaryContainer,
                        ),
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            if (!value.startsWith('http://') &&
                                !value.startsWith('https://')) {
                              return l10n.profileEditSocialUrlInvalidError;
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      // Artist-specific section (only shown for verified artists)
                      if (_isArtist) ...[
                        _buildSectionHeader(
                          l10n.profileEditArtistInformationTitle,
                          Icons.palette,
                        ),
                        const SizedBox(height: 16),

                        // Specialty
                        Text(
                          l10n.profileEditArtistSpecialtiesLabel,
                          style: KubusTypography.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _specialtyController,
                          decoration: InputDecoration(
                            hintText: l10n.profileEditArtistSpecialtiesHint,
                            helperText: l10n.profileEditArtistSpecialtiesHelper,
                            prefixIcon: const Icon(Icons.brush),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor:
                                Theme.of(context).colorScheme.primaryContainer,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Years Active
                        Text(
                          l10n.profileEditArtistYearsActiveLabel,
                          style: KubusTypography.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _yearsActiveController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: l10n.profileEditArtistYearsActiveHint,
                            prefixIcon: const Icon(Icons.calendar_today),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor:
                                Theme.of(context).colorScheme.primaryContainer,
                          ),
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              final years = int.tryParse(value);
                              if (years == null || years < 0) {
                                return l10n
                                    .profileEditArtistYearsActiveInvalidError;
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),
                      ],

                      // Institution-specific section (only shown for verified institutions)
                      if (_isInstitution) ...[
                        _buildSectionHeader(
                          l10n.profileEditInstitutionInformationTitle,
                          Icons.business,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.profileEditInstitutionAboutTitle,
                          style: KubusTypography.inter(
                            fontSize: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: themeProvider.accentColor,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  l10n.profileEditInstitutionAboutBody,
                                  style: KubusTypography.inter(
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],

                      // Privacy Settings Section
                      _buildSectionHeader(l10n.settingsPrivacySettingsTileTitle,
                          Icons.security),
                      const SizedBox(height: 16),

                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildPrivacySwitch(
                              l10n.settingsPrivateProfileTitle,
                              l10n.settingsPrivateProfileSubtitle,
                              Icons.lock_outline,
                              _privateProfile,
                              (value) =>
                                  setState(() => _privateProfile = value),
                              switchKey: const Key(
                                  'profile_edit_privacy_private_profile'),
                            ),
                            _buildDivider(),
                            _buildPrivacySwitch(
                              l10n.settingsShowActivityStatusTitle,
                              l10n.settingsShowActivityStatusSubtitle,
                              Icons.circle,
                              _showActivityStatus,
                              (value) => setState(() {
                                _showActivityStatus = value;
                                if (!value) _shareLastVisitedLocation = false;
                              }),
                              switchKey: const Key(
                                  'profile_edit_privacy_show_activity_status'),
                            ),
                            _buildDivider(),
                            _buildPrivacySwitch(
                              l10n.settingsShareLastVisitedLocationTitle,
                              l10n.settingsShareLastVisitedLocationSubtitle,
                              Icons.place_outlined,
                              _shareLastVisitedLocation,
                              (value) => setState(
                                  () => _shareLastVisitedLocation = value),
                              enabled: _showActivityStatus,
                              switchKey: const Key(
                                  'profile_edit_privacy_share_last_visited_location'),
                            ),
                            _buildDivider(),
                            _buildPrivacySwitch(
                              l10n.settingsShowCollectionTitle,
                              l10n.settingsShowCollectionSubtitle,
                              Icons.collections,
                              _showCollection,
                              (value) =>
                                  setState(() => _showCollection = value),
                              switchKey: const Key(
                                  'profile_edit_privacy_show_collection'),
                            ),
                            _buildDivider(),
                            _buildPrivacySwitch(
                              l10n.settingsAllowMessagesTitle,
                              l10n.settingsAllowMessagesSubtitle,
                              Icons.message_outlined,
                              _allowMessages,
                              (value) => setState(() => _allowMessages = value),
                              switchKey: const Key(
                                  'profile_edit_privacy_allow_messages'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Role Status (read-only display)
                      if (_isArtist || _isInstitution) ...[
                        _buildSectionHeader(
                          l10n.profileEditVerifiedStatusTitle,
                          Icons.verified,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                themeProvider.accentColor
                                    .withValues(alpha: 0.1),
                                themeProvider.accentColor
                                    .withValues(alpha: 0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: themeProvider.accentColor
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: themeProvider.accentColor
                                      .withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isInstitution
                                      ? Icons.business
                                      : Icons.palette,
                                  color: themeProvider.accentColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isInstitution
                                          ? l10n
                                              .profileEditVerifiedInstitutionTitle
                                          : l10n.profileEditVerifiedArtistTitle,
                                      style: KubusTypography.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _isInstitution
                                          ? l10n
                                              .profileEditVerifiedInstitutionSubtitle
                                          : l10n
                                              .profileEditVerifiedArtistSubtitle,
                                      style: KubusTypography.inter(
                                        fontSize: 13,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                                size: 28,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    return Row(
      children: [
        Icon(
          icon,
          color: themeProvider.accentColor,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: KubusTypography.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacySwitch(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged, {
    bool enabled = true,
    Key? switchKey,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: enabled
                ? (value
                    ? themeProvider.accentColor
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5))
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.38),
            size: 22,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: KubusTypography.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: KubusTypography.inter(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            key: switchKey,
            value: value,
            onChanged: enabled ? onChanged : null,
            activeTrackColor: themeProvider.accentColor.withValues(alpha: 0.5),
            thumbColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? themeProvider.accentColor
                    : null),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 54,
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
    );
  }

  String? _normalizeMediaUrl(String? url) {
    return MediaUrlResolver.resolve(url);
  }
}
