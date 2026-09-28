import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../utils/design_tokens.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as path;
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../providers/app_mode_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/dao_provider.dart';
import '../../services/backend_api_service.dart';
import '../../models/user.dart';
import '../../models/user_profile.dart';
import '../../models/dao.dart';
import '../../services/event_bus.dart';
import '../../providers/themeprovider.dart';
import '../../utils/profile_edit_form_utils.dart';
import '../../utils/profile_media_ref_utils.dart';
import '../../widgets/inline_loading.dart';
import '../../utils/media_url_resolver.dart';
import 'package:art_kubus/widgets/app_mode_unavailable_state.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:art_kubus/widgets/forms/kubus_form.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
import 'package:art_kubus/widgets/profile/profile_edit_form_body.dart';
import '../../utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/common/keyboard_inset_padding.dart';
import '../../widgets/avatar_widget.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key, this.isOnboarding = false});

  final bool isOnboarding;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final KubusFormSubmitState _submit = KubusFormSubmitState();
  final ScrollController _scrollController = ScrollController();

  /// Form-level message: validation summary or save failure.
  String? _formNotice;
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
  bool _isUploadingAvatar = false;
  bool _avatarChanged = false;
  bool _isUploadingCover = false;
  bool _coverChanged = false;
  bool _isSavingProfile = false;
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
    _avatarUrl = _editableAvatarRef(profile?.avatar);
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

    // Listen to profile provider changes without clobbering local upload/edit state.
    _profileListener = () {
      if (!mounted) return;
      _syncMediaFromProvider(profileProvider.currentUser);
    };
    profileProvider.addListener(_profileListener!);
  }

  String? _editableAvatarRef(String? value) {
    final avatar = value?.trim();
    if (avatar == null ||
        avatar.isEmpty ||
        ProfileMediaRefUtils.isGeneratedAvatarRef(avatar)) {
      return null;
    }
    return avatar;
  }

  void _syncMediaFromProvider(UserProfile? profile) {
    final nextAvatar = _editableAvatarRef(profile?.avatar);
    final nextCoverDisplay = _normalizeMediaUrl(profile?.coverImage);

    setState(() {
      if (!_isUploadingAvatar && !_avatarChanged) {
        _avatarUrl = nextAvatar;
      }

      if (!_isUploadingCover && !_coverChanged) {
        _coverImageUrl = nextCoverDisplay;
      }
    });
  }

  @visibleForTesting
  String? get debugAvatarUrl => _avatarUrl;

  @visibleForTesting
  String? get debugCoverImageUrl => _coverImageUrl;

  @visibleForTesting
  bool get debugIsUploadingAvatar => _isUploadingAvatar;

  @visibleForTesting
  bool get debugIsUploadingCover => _isUploadingCover;

  @visibleForTesting
  bool get debugIsSavingProfile => _isSavingProfile;

  @visibleForTesting
  bool get debugAvatarChanged => _avatarChanged;

  @visibleForTesting
  bool get debugCoverChanged => _coverChanged;

  @visibleForTesting
  bool get debugHasLocalAvatarBytes => _localAvatarBytes != null;

  @visibleForTesting
  bool get debugHasLocalCoverBytes => _localCoverBytes != null;

  @visibleForTesting
  void debugSetMediaSyncState({
    bool? isUploadingAvatar,
    bool? isUploadingCover,
    bool? avatarChanged,
    bool? coverChanged,
  }) {
    setState(() {
      _isUploadingAvatar = isUploadingAvatar ?? _isUploadingAvatar;
      _isUploadingCover = isUploadingCover ?? _isUploadingCover;
      _avatarChanged = avatarChanged ?? _avatarChanged;
      _coverChanged = coverChanged ?? _coverChanged;
    });
  }

  @visibleForTesting
  Future<void> debugUploadAvatarBytesForTesting({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) {
    return _uploadAvatarBytes(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
    );
  }

  @visibleForTesting
  Future<void> debugUploadCoverBytesForTesting({
    required Uint8List bytes,
    required String fileName,
  }) {
    return _uploadCoverBytes(bytes: bytes, fileName: fileName);
  }

  @visibleForTesting
  Future<void> debugSaveProfileForTesting() => _saveProfile();

  @override
  void dispose() {
    _scrollController.dispose();
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
        final bytes = await image.readAsBytes();
        if (!mounted) return;
        final fileName =
            (image.name.isNotEmpty) ? image.name : path.basename(image.path);
        await _uploadAvatarBytes(
          bytes: bytes,
          fileName: fileName,
          mimeType: image.mimeType,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(l10n.profileEditPickImageFailedToast),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _uploadAvatarBytes({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    setState(() {
      _localAvatarBytes = bytes;
      _isUploadingAvatar = true;
    });

    var succeeded = false;
    try {
      final wallet = profileProvider.currentUser?.walletAddress ?? '';

      if (wallet.isEmpty) {
        messenger.showKubusSnackBar(
          SnackBar(
            content: Text(l10n.profileEditNoWalletUploadAvatarToast),
            backgroundColor: colorScheme.error,
          ),
        );
        return;
      }

      final uploadedRef = await profileProvider.uploadAvatarBytes(
        fileBytes: bytes,
        fileName: fileName,
        walletAddress: wallet,
        mimeType: mimeType,
      );

      final persistableAvatar = _toPersistableAvatarRef(uploadedRef);
      if (persistableAvatar == null || persistableAvatar.isEmpty) {
        throw Exception('Failed to get uploaded avatar ref');
      }

      _avatarChanged = true;

      final saved = await profileProvider.saveProfile(
        walletAddress: wallet,
        avatar: persistableAvatar,
        reloadStats: false,
      );
      if (!saved) {
        throw Exception(profileProvider.error ?? 'Avatar save failed');
      }

      succeeded = true;
      if (!mounted) return;
      setState(() {
        _avatarUrl = persistableAvatar;
        _localAvatarBytes = null;
        _avatarChanged = false;
      });

      unawaited(profileProvider.loadProfile(wallet));
      if (kDebugMode) {
        final displayAvatarUrl =
            _normalizeMediaUrl(persistableAvatar) ?? persistableAvatar;
        final uri = Uri.tryParse(displayAvatarUrl);
        messenger.showKubusSnackBar(
          SnackBar(
            duration: const Duration(seconds: 6),
            content: Row(
              children: [
                Expanded(
                  child: Text(
                    displayAvatarUrl,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20, color: Colors.white),
                  onPressed: () async {
                    final activeMessenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(
                        ClipboardData(text: displayAvatarUrl));
                    if (!mounted) return;
                    activeMessenger.showKubusSnackBar(
                      SnackBar(
                        content:
                            Text(l10n.profileEditAvatarCopiedToClipboardToast),
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
      }

      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.profileEditAvatarUploadedSavedToast),
          backgroundColor: colorScheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    } on TimeoutException catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('ProfileEditScreen: avatar upload timed out: $e');
        debugPrint('$stackTrace');
      }
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.profileEditAvatarUploadTimeoutToast),
          backgroundColor: colorScheme.error,
        ),
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('ProfileEditScreen: avatar upload failed: $e');
        debugPrint('$stackTrace');
      }
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.profileEditAvatarUploadFailedToast),
          backgroundColor: colorScheme.error,
        ),
      );

      final debug = profileProvider.lastUploadDebug;
      if (kDebugMode && debug != null) {
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
                  final activeMessenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(ClipboardData(text: pretty));
                  if (!mounted) return;
                  navigator.pop();
                  activeMessenger.showKubusSnackBar(
                    SnackBar(
                      content: Text(l10n.profileEditUploadDebugInfoCopiedToast),
                    ),
                  );
                },
                child: Text(l10n.commonCopy),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
          if (!succeeded) {
            _avatarChanged = false;
            _localAvatarBytes = null;
          }
        });
      }
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
        final fileName =
            (image.name.isNotEmpty) ? image.name : path.basename(image.path);
        await _uploadCoverBytes(bytes: bytes, fileName: fileName);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(l10n.profileEditPickImageFailedToast),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _uploadCoverBytes({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    setState(() {
      _localCoverBytes = bytes;
      _isUploadingCover = true;
    });

    var succeeded = false;
    try {
      final wallet = profileProvider.currentUser?.walletAddress ?? '';

      if (wallet.isEmpty) {
        messenger.showKubusSnackBar(
          SnackBar(
            content: Text(l10n.profileEditNoWalletUploadCoverToast),
            backgroundColor: colorScheme.error,
          ),
        );
        return;
      }

      final result = await profileProvider.uploadProfileCoverBytes(
        fileBytes: bytes,
        fileName: fileName,
        walletAddress: wallet,
      );

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

      final persistableCover = _toPersistableCoverRef(uploadedRef);
      if (persistableCover == null || persistableCover.isEmpty) {
        throw Exception('Failed to normalize uploaded cover ref');
      }

      _coverChanged = true;

      final saved = await profileProvider.saveProfile(
        walletAddress: wallet,
        coverImage: persistableCover,
        reloadStats: false,
      );
      if (!saved) {
        throw Exception(profileProvider.error ?? 'Cover save failed');
      }

      if (!mounted) return;
      succeeded = true;
      setState(() {
        _coverImageUrl = persistableCover;
        _localCoverBytes = null;
        _coverChanged = false;
      });
      unawaited(profileProvider.loadProfile(wallet));
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.profileEditCoverUploadedSavedToast),
          backgroundColor: colorScheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    } on TimeoutException catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('ProfileEditScreen: cover upload timed out: $e');
        debugPrint('$stackTrace');
      }
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.profileEditCoverUploadTimeoutToast),
          backgroundColor: colorScheme.error,
        ),
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('ProfileEditScreen: cover upload failed: $e');
        debugPrint('$stackTrace');
      }
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.profileEditCoverUploadFailedToast),
          backgroundColor: colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingCover = false;
          if (!succeeded) {
            _coverChanged = false;
            _localCoverBytes = null;
          }
        });
      }
    }
  }

  void _showFormNotice(String? message) {
    setState(() => _formNotice = message);
    if (message != null && _scrollController.hasClients) {
      unawaited(_scrollController.animateTo(
        0,
        duration: MediaQuery.of(context).disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      ));
    }
  }

  Future<void> _saveProfile() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_submit.validate(_formKey)) {
      _showFormNotice(l10n.formFixHighlightedFields);
      return;
    }

    setState(() {
      _isSavingProfile = true;
      _formNotice = null;
    });

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
        avatar: _avatarChanged ? _toPersistableAvatarRef(_avatarUrl) : null,
        coverImage:
            _coverChanged ? _toPersistableCoverRef(_coverImageUrl) : null,
        social: {
          'twitter': _twitterController.text.trim(),
          'instagram': _instagramController.text.trim(),
          'website': ProfileEditFormUtils.normalizeWebsiteForSave(
            _websiteController.text,
          ),
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
      final errorText = e.toString().contains('Profile save timed out')
          ? l10n.profileEditSaveTimeoutToast
          : l10n.profileEditErrorToast;
      if (kDebugMode) {
        debugPrint('ProfileEditScreen: profile save failed: $e');
      }
      // Save failures stay on the form (inline, announced) so the draft
      // and the reason are visible together; no transient toast.
      _showFormNotice(errorText);
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
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
    displayUrl = _normalizeMediaUrl(displayUrl) ?? displayUrl;

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

  void _onPrivacyChanged(ProfilePrivacyField field, bool value) {
    setState(() {
      switch (field) {
        case ProfilePrivacyField.privateProfile:
          _privateProfile = value;
        case ProfilePrivacyField.showActivityStatus:
          _showActivityStatus = value;
          if (!value) _shareLastVisitedLocation = false;
        case ProfilePrivacyField.shareLastVisitedLocation:
          _shareLastVisitedLocation = value;
        case ProfilePrivacyField.showCollection:
          _showCollection = value;
        case ProfilePrivacyField.allowMessages:
          _allowMessages = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final appModeProvider = context.watch<AppModeProvider?>();
    final isIpfsFallbackMode = appModeProvider?.isIpfsFallbackMode ?? false;
    const avatarDiameter = 96.0;
    final avatarFrameRadius = AvatarWidget.shapeRadiusFor(
      radius: avatarDiameter / 2,
      cornerRadiusFactor: AvatarWidget.defaultCornerRadiusFactor,
    );
    final hasCover = _localCoverBytes != null ||
        (_coverImageUrl != null && _coverImageUrl!.isNotEmpty);
    final hasAvatar = _localAvatarBytes != null ||
        (_avatarUrl != null && _avatarUrl!.isNotEmpty);
    final ImageProvider? coverImage = _localCoverBytes != null
        ? MemoryImage(_localCoverBytes!)
        : (hasCover ? NetworkImage(_coverImageUrl!) : null);

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: l10n.commonBack,
          icon: Icon(Icons.arrow_back, color: roles.foreground),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.profileEditTitle,
          style: KubusTextStyles.mobileAppBarTitle.copyWith(
            color: roles.foreground,
          ),
        ),
        actions: [
          if (!isIpfsFallbackMode)
            Padding(
              padding: const EdgeInsets.only(right: KubusSpacing.sm),
              child: TextButton(
                onPressed: _isSavingProfile ? null : _saveProfile,
                style: TextButton.styleFrom(
                  foregroundColor: roles.foreground,
                  minimumSize: const Size(48, 48),
                  textStyle: KubusTextStyles.actionLabel,
                ),
                child: Text(l10n.commonSave),
              ),
            ),
        ],
      ),
      body: isIpfsFallbackMode
          ? AppModeUnavailableState(
              featureLabel: l10n.profileEditTitle,
              title: l10n.stateUnsupportedTitle,
              icon: Icons.person_outline,
            )
          : KeyboardInsetPadding(
              child: SingleChildScrollView(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  KubusSpacing.md,
                  KubusSpacing.sm,
                  KubusSpacing.md,
                  KubusSpacing.xl,
                ),
                child: KubusFormMeasure(
                  child: Form(
                    key: _formKey,
                    autovalidateMode: _submit.autovalidateMode,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ProfileEditFormBody(
                          formNotice: _formNotice,
                          controllers: ProfileEditControllers(
                            username: _usernameController,
                            displayName: _displayNameController,
                            bio: _bioController,
                            twitter: _twitterController,
                            instagram: _instagramController,
                            website: _websiteController,
                            specialty: _specialtyController,
                            yearsActive: _yearsActiveController,
                          ),
                          isArtist: _isArtist,
                          isInstitution: _isInstitution,
                          privacy: ProfilePrivacyDraft(
                            privateProfile: _privateProfile,
                            showActivityStatus: _showActivityStatus,
                            shareLastVisitedLocation: _shareLastVisitedLocation,
                            showCollection: _showCollection,
                            allowMessages: _allowMessages,
                          ),
                          onPrivacyChanged: _onPrivacyChanged,
                          coverPreview: ProfileEditCoverPreview(
                            isBusy: _isUploadingCover,
                            image: coverImage,
                          ),
                          hasCover: hasCover,
                          onPickCover: _pickCoverImage,
                          isUploadingCover: _isUploadingCover,
                          avatarPreview: ExcludeSemantics(
                            child: Container(
                              width: avatarDiameter,
                              height: avatarDiameter,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: roles.surfaceRaised,
                                borderRadius:
                                    BorderRadius.circular(avatarFrameRadius),
                                border: Border.all(color: roles.rule),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  hasAvatar
                                      ? _buildAvatarWidget(
                                          _avatarUrl ?? '', themeProvider)
                                      : Icon(
                                          Icons.person_outline,
                                          size: 40,
                                          color: roles.foregroundSubtle,
                                        ),
                                  if (_isUploadingAvatar)
                                    ColoredBox(
                                      color:
                                          roles.ground.withValues(alpha: 0.6),
                                      child: const Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: InlineLoading(
                                            expand: true,
                                            shape: BoxShape.circle,
                                            tileSize: 3.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          hasAvatar: hasAvatar,
                          onPickAvatar: _pickAvatar,
                          isUploadingAvatar: _isUploadingAvatar,
                        ),
                        const SizedBox(height: KubusSpacing.xl),
                        KubusButton(
                          onPressed: _saveProfile,
                          isLoading: _isSavingProfile,
                          isFullWidth: true,
                          label: l10n.profileEditSaveChanges,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  String? _normalizeMediaUrl(String? url) {
    return MediaUrlResolver.resolve(url);
  }

  String? _toPersistableAvatarRef(String? value) =>
      ProfileMediaRefUtils.toPersistableAvatarRef(value);

  String? _toPersistableCoverRef(String? value) =>
      ProfileMediaRefUtils.toPersistableCoverRef(value);
}
